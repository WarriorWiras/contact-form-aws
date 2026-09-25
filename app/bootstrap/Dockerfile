FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY bootstrap/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY bootstrap/bootstrap.py bootstrap.py
COPY bootstrap/verify.py verify.py
COPY schema.sql schema.sql
USER 10001:10001
CMD ["python", "bootstrap.py"]
