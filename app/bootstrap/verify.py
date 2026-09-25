"""Read recent demo rows as a separate PostgreSQL SELECT-only role."""

import json
import os

import boto3
import psycopg


client = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])
credential = json.loads(client.get_secret_value(
    SecretId=os.environ["VERIFIER_SECRET_ARN"]
)["SecretString"])

with psycopg.connect(
    host=os.environ["DB_HOST"],
    dbname=os.environ["DB_NAME"],
    user=credential["username"],
    password=credential["password"],
    sslmode="require",
    connect_timeout=10,
) as connection:
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT id, name, email, message FROM contact_messages "
            "ORDER BY id DESC LIMIT 5"
        )
        for row in cursor.fetchall():
            print(f"id={row[0]} name={row[1]!r} email={row[2]!r} message={row[3]!r}")
