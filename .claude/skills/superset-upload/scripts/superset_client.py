"""Minimal REST client for pushing data into Apache Superset.

Wraps the three calls needed to get a local file registered as a queryable
Superset dataset:

1. POST /api/v1/security/login       -> JWT access token
2. GET  /api/v1/security/csrf_token/ -> CSRF token (tied to the session cookie)
3. POST /api/v1/database/{id}/upload/ -> multipart file upload

Superset validates the CSRF token against the Flask session cookie, so the
same `requests.Session` (cookie jar) must be reused across steps 2 and 3.
"""

from __future__ import annotations

import mimetypes
from pathlib import Path
from typing import Any

import requests

UPLOAD_FILE_TYPES = {
    ".csv": "csv",
    ".tsv": "csv",
    ".xls": "excel",
    ".xlsx": "excel",
    ".parquet": "columnar",
    ".zip": "columnar",
}


class SupersetAPIError(RuntimeError):
    def __init__(self, response: requests.Response):
        self.response = response
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        super().__init__(f"Superset API error {response.status_code}: {detail}")


class SupersetClient:
    def __init__(self, base_url: str, username: str, password: str, verify: bool = True):
        self.base_url = base_url.rstrip("/")
        self.username = username
        self.password = password
        self.verify = verify
        self.session = requests.Session()
        self._access_token: str | None = None
        self._csrf_token: str | None = None

    # -- auth -----------------------------------------------------------

    def login(self) -> None:
        resp = self.session.post(
            f"{self.base_url}/api/v1/security/login",
            json={
                "username": self.username,
                "password": self.password,
                "provider": "db",
                "refresh": True,
            },
            verify=self.verify,
        )
        if resp.status_code != 200:
            raise SupersetAPIError(resp)
        self._access_token = resp.json()["access_token"]

        csrf_resp = self.session.get(
            f"{self.base_url}/api/v1/security/csrf_token/",
            headers=self._auth_headers(),
            verify=self.verify,
        )
        if csrf_resp.status_code != 200:
            raise SupersetAPIError(csrf_resp)
        self._csrf_token = csrf_resp.json()["result"]

    def _auth_headers(self, mutating: bool = False) -> dict[str, str]:
        if self._access_token is None:
            raise RuntimeError("Call login() first")
        headers = {"Authorization": f"Bearer {self._access_token}"}
        if mutating:
            headers["X-CSRFToken"] = self._csrf_token
        return headers

    def _request(self, method: str, path: str, **kwargs: Any) -> requests.Response:
        mutating = method.upper() in {"POST", "PUT", "DELETE"}
        headers = kwargs.pop("headers", {})
        headers.update(self._auth_headers(mutating=mutating))
        resp = self.session.request(
            method, f"{self.base_url}{path}", headers=headers, verify=self.verify, **kwargs
        )
        if resp.status_code >= 400:
            raise SupersetAPIError(resp)
        return resp

    # -- databases --------------------------------------------------------

    def list_databases(self) -> list[dict[str, Any]]:
        return self._request("GET", "/api/v1/database/").json()["result"]

    def find_database_id(self, name: str) -> int | None:
        for db in self.list_databases():
            if db["database_name"] == name:
                return db["id"]
        return None

    def ensure_database(
        self,
        name: str,
        sqlalchemy_uri: str,
        schemas_allowed_for_file_upload: list[str] | None = None,
    ) -> int:
        """Return the id of an upload-enabled database, creating it if needed."""
        existing_id = self.find_database_id(name)
        if existing_id is not None:
            return existing_id

        import json as _json

        payload = {
            "database_name": name,
            "sqlalchemy_uri": sqlalchemy_uri,
            "allow_file_upload": True,
            "expose_in_sqllab": True,
            "extra": _json.dumps(
                {"schemas_allowed_for_file_upload": schemas_allowed_for_file_upload or ["public"]}
            ),
        }
        resp = self._request("POST", "/api/v1/database/", json=payload)
        return resp.json()["id"]

    # -- upload -----------------------------------------------------------

    def upload_file(
        self,
        database_id: int,
        file_path: str | Path,
        table_name: str,
        schema: str = "public",
        already_exists: str = "fail",
        file_type: str | None = None,
        delimiter: str | None = None,
        sheet_name: str | None = None,
        header_row: int | None = None,
    ) -> dict[str, Any]:
        """Upload a CSV/Excel/Parquet file, creating or updating a Superset table.

        already_exists: "fail" | "replace" | "append"
        """
        file_path = Path(file_path)
        if not file_path.exists():
            raise FileNotFoundError(file_path)

        resolved_type = file_type or UPLOAD_FILE_TYPES.get(file_path.suffix.lower())
        if resolved_type is None:
            raise ValueError(f"Cannot infer upload type for extension {file_path.suffix!r}")

        data = {
            "type": resolved_type,
            "table_name": table_name,
            "schema": schema,
            "already_exists": already_exists,
        }
        if delimiter and resolved_type == "csv":
            data["delimiter"] = delimiter
        if sheet_name and resolved_type == "excel":
            data["sheet_name"] = sheet_name
        if header_row is not None:
            data["header_row"] = str(header_row)

        content_type = mimetypes.guess_type(file_path.name)[0] or "application/octet-stream"
        with open(file_path, "rb") as fh:
            files = {"file": (file_path.name, fh, content_type)}
            resp = self._request(
                "POST", f"/api/v1/database/{database_id}/upload/", data=data, files=files
            )
        return resp.json()

    # -- datasets -----------------------------------------------------------

    def find_dataset(self, table_name: str) -> dict[str, Any] | None:
        # Superset's list endpoints take Rison, not JSON, in the `q` param.
        rison_query = f"(filters:!((col:table_name,opr:eq,value:{table_name})))"
        resp = self._request(
            "GET", "/api/v1/dataset/", params={"q": rison_query}
        )
        result = resp.json()
        return result["result"][0] if result["count"] else None
