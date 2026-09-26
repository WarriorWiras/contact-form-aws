# Flask app: receive and save a message

The browser shows a form with **name, email and message**. Flask checks the input and saves valid submissions in the RDS PostgreSQL table `contact_messages`. It uses placeholders in the SQL query so form text is treated as data. After a successful submission, it sends the visitor back to the form with a success message.

The main files are:

| File | What it does |
| --- | --- |
| `contact_form.py` | Handles the form, saves a message and checks health. |
| `templates/contact.html` | Shows the page and form fields. |
| `schema.sql` | Defines the database table. |
| `bootstrap/bootstrap.py` | Sets up the table and limited database users inside EKS. |
| `bootstrap/verify.py` | Reads recent demo entries using a separate read-only user. |
| `Dockerfile` | Packages Flask for EKS and runs it as user `10001`, not root. |
| `tests/test_contact_form.py` | Tests good/bad inputs, saved values and health responses. |

## Where the database password comes from

Terraform asks RDS to generate its **master password** in AWS Secrets Manager. The database setup Job generates a different **app password**, creates an app user with only the access it needs to insert messages, and writes that password to Secrets Manager. It also creates a separate user that can only read rows for the demo.

In EKS, the AWS Secrets Store CSI driver places the app secret into a file that only the Flask Pod mounts. Flask reads that file using `DB_SECRET_FILE`. `DB_HOST` and `DB_NAME` tell it where to connect; they are not passwords. No database password is written into the source code or Kubernetes manifests.

Flask normally asks for an encrypted PostgreSQL connection (`DB_SSLMODE=require`). `DB_SSLMODE=disable` was used **only** for a temporary local PostgreSQL container without TLS. Do not set it for RDS/EKS.

## Run the quick tests on your laptop

From the main repository folder:

```bash
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r app/requirements.txt
cd app
python -m unittest discover -s tests -v
cd ..
```

The four Python tests do not need AWS or a real database. They use a fake database connection to check the app's behavior. In the AWS deployment, a fictional form submission was also verified in **real RDS** with `./scripts/verify.sh`.

For the live app, `/health/live` checks that Flask responds; `/health/ready` checks that Flask can reach PostgreSQL. The ALB uses the second one.
