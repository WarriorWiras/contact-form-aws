"""Initialize a restricted application role without exposing DB passwords to Terraform."""

import json
import os
import secrets
from pathlib import Path

import boto3
import psycopg
from psycopg import sql


APP_ROLE = "contactapp"
VERIFIER_ROLE = "contactreader"


def get_existing_secret(client, arn):
    try:
        return json.loads(client.get_secret_value(SecretId=arn)["SecretString"])
    except client.exceptions.ResourceNotFoundException:
        # Terraform created the metadata without a secret version.
        return None


def ensure_login(cursor, role, password, has_existing_secret):
    cursor.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (role,))
    exists = cursor.fetchone() is not None
    if not exists:
        cursor.execute(sql.SQL("CREATE ROLE {} LOGIN PASSWORD {}").format(
            sql.Identifier(role), sql.Literal(password)
        ))
    elif not has_existing_secret:
        # Recover when role creation succeeded but the first secret write did not.
        cursor.execute(sql.SQL("ALTER ROLE {} PASSWORD {}").format(
            sql.Identifier(role), sql.Literal(password)
        ))


def main():
    client = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])
    master = json.loads(client.get_secret_value(
        SecretId=os.environ["MASTER_SECRET_ARN"]
    )["SecretString"])

    app_secret = get_existing_secret(client, os.environ["APP_SECRET_ARN"])
    verifier_secret = get_existing_secret(client, os.environ["VERIFIER_SECRET_ARN"])
    app_password = app_secret["password"] if app_secret else secrets.token_urlsafe(36)
    verifier_password = (
        verifier_secret["password"] if verifier_secret else secrets.token_urlsafe(36)
    )
    with psycopg.connect(
        host=os.environ["DB_HOST"],
        dbname=os.environ["DB_NAME"],
        user=master["username"],
        password=master["password"],
        sslmode="require",
        connect_timeout=10,
        autocommit=True,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute(Path("/app/schema.sql").read_text(encoding="utf-8"))
            ensure_login(cursor, APP_ROLE, app_password, app_secret is not None)
            ensure_login(
                cursor, VERIFIER_ROLE, verifier_password,
                verifier_secret is not None,
            )
            for role in (APP_ROLE, VERIFIER_ROLE):
                cursor.execute(sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
                    sql.Identifier(os.environ["DB_NAME"]), sql.Identifier(role)
                ))
                cursor.execute(sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(
                    sql.Identifier(role)
                ))
            cursor.execute(sql.SQL("GRANT INSERT ON contact_messages TO {}").format(
                sql.Identifier(APP_ROLE)
            ))
            cursor.execute(sql.SQL("GRANT USAGE ON SEQUENCE contact_messages_id_seq TO {}").format(
                sql.Identifier(APP_ROLE)
            ))
            cursor.execute(sql.SQL("GRANT SELECT ON contact_messages TO {}").format(
                sql.Identifier(VERIFIER_ROLE)
            ))

    if app_secret is None:
        client.put_secret_value(
            SecretId=os.environ["APP_SECRET_ARN"],
            SecretString=json.dumps({"username": APP_ROLE, "password": app_password}),
        )
    if verifier_secret is None:
        client.put_secret_value(
            SecretId=os.environ["VERIFIER_SECRET_ARN"],
            SecretString=json.dumps({
                "username": VERIFIER_ROLE, "password": verifier_password,
            }),
        )
    print("Database schema and restricted application and verifier roles are ready.")


if __name__ == "__main__":
    main()
