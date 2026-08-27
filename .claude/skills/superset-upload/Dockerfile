FROM python:3.12-slim
ARG HTTP_PROXY
ARG HTTPS_PROXY
RUN pip install --no-cache-dir requests
COPY scripts/ /app/
WORKDIR /app
ENTRYPOINT ["python", "/app/upload_to_superset.py"]
