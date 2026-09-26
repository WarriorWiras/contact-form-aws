# Flask contact form

The page has three fields: name, email and message. `contact_form.py` checks them and saves valid entries to the `contact_messages` table in PostgreSQL. The HTML page is in `templates/contact.html`; the table definition is in `schema.sql`.

The app gets its database login from a file mounted into its EKS Pod. The file comes from AWS Secrets Manager through the Secrets Store CSI driver. `DB_SECRET_FILE` holds the **file path**, not the password. The database host and name come from Kubernetes settings.

`bootstrap/bootstrap.py` runs during deployment. It creates the table and two database users. The app user can insert messages. The verifier user can only read them for the demo. RDS creates the separate master password. None of these passwords is fixed in the source code.

The Docker image runs Flask with Gunicorn as user `10001`, not root. `/health/live` checks that Flask is responding. `/health/ready` also checks the database, which is why the ALB uses it.

Local Python tests, from the project root:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r app/requirements.txt
cd app
python -m unittest discover -s tests -v
cd ..
```

These four tests use a fake database connection, so AWS is not needed. The live AWS test was separate: a fictional form submission was read back from RDS using `./scripts/verify.sh`.

Database connections normally request TLS with `DB_SSLMODE=require`. The `disable` option was only for a temporary local PostgreSQL container without TLS; it is not set in EKS.
