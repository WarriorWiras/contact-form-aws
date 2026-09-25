"""Small contact form served behind an ALB, with a private PostgreSQL backend."""

import json
import os
import re

import psycopg
from flask import Flask, redirect, render_template, request, url_for


EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
INSERT = "INSERT INTO contact_messages (name, email, message) VALUES (%s, %s, %s)"


def database_settings():
    """Read the CSI-mounted application secret for each new connection."""
    with open(os.environ["DB_SECRET_FILE"], encoding="utf-8") as secret_file:
        secret = json.load(secret_file)
    return {
        "host": os.environ["DB_HOST"],
        "port": int(os.getenv("DB_PORT", "5432")),
        "dbname": os.environ["DB_NAME"],
        "user": secret["username"],
        "password": secret["password"],
        "sslmode": os.getenv("DB_SSLMODE", "require"),
        "connect_timeout": 3,
    }


def create_app(connect=None):
    application = Flask(__name__)
    connect = connect or (lambda: psycopg.connect(**database_settings()))

    @application.after_request
    def disable_sensitive_cache(response):
        response.headers["Cache-Control"] = "no-store"
        return response

    @application.get("/health/live")
    def live():
        return "ok", 200

    @application.get("/health/ready")
    def ready():
        try:
            with connect() as connection:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
        except (OSError, KeyError, ValueError, psycopg.Error):
            return "unavailable", 503
        return "ready", 200

    @application.get("/")
    def form():
        return render_template("contact.html", submitted=request.args.get("submitted") == "1")

    @application.post("/contact")
    def submit():
        name = request.form.get("name", "").strip()
        email = request.form.get("email", "").strip()
        message = request.form.get("message", "").strip()
        if not (1 <= len(name) <= 100 and 1 <= len(email) <= 254
                and EMAIL_PATTERN.fullmatch(email) and 1 <= len(message) <= 2000):
            return render_template(
                "contact.html", error="Please check all three fields and try again.",
                name=name, email=email, message=message,
            ), 400
        try:
            with connect() as connection:
                with connection.cursor() as cursor:
                    cursor.execute(INSERT, (name, email, message))
        except (OSError, KeyError, ValueError, psycopg.Error):
            return render_template(
                "contact.html", error="The form is temporarily unavailable. Please try again.",
                name=name, email=email, message=message,
            ), 503
        return redirect(url_for("form", submitted="1"), code=303)

    return application


app = create_app()
