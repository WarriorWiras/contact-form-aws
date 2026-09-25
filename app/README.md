# Flask contact form

The app accepts a name, email and message, validates the input, and inserts it into PostgreSQL with a parameterized query. It reads the `username` and `password` fields from the JSON file mounted by the Secrets Store CSI Driver. `DB_SECRET_FILE` is the file path, not the credential value. The database host, name and port are non-secret settings supplied by Kubernetes.

The database bootstrap phase must create the table from `schema.sql` and give the separate application role only `CONNECT`, `USAGE` on its schema, `INSERT` on `contact_messages` and `USAGE` on its sequence. A separate verification identity will query submitted rows for the demo.

Local development requires Python 3.12+, PostgreSQL, a credential JSON file outside Git and the configuration `DB_HOST`, `DB_NAME`, `DB_SECRET_FILE`. Install `requirements.txt` in a virtual environment. Run `python -m unittest discover -s tests -v` for application behavior tests. Docker builds use the non-root user `10001` and serve the app with Gunicorn on port 8000.

No AWS resources are required to build or test this application. Its connection to EKS/RDS remains unverified until deployment.
