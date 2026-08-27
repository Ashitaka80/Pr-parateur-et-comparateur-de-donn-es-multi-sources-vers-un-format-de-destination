FROM python:3.12-slim
# Aucune dépendance externe : normalisation/similarité en stdlib pur
# (unicodedata, difflib) — voir SKILL.md.
COPY scripts/ /app/scripts/
COPY tests/ /app/tests/
WORKDIR /app
ENTRYPOINT ["python", "scripts/compare_sources.py"]
