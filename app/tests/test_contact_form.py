import unittest
from unittest.mock import MagicMock, Mock

from contact_form import INSERT, create_app


class ContactFormTests(unittest.TestCase):
    def setUp(self):
        self.cursor = MagicMock()
        connection = MagicMock()
        connection.__enter__.return_value = connection
        connection.cursor.return_value.__enter__.return_value = self.cursor
        self.connect = Mock(return_value=connection)
        self.client = create_app(self.connect).test_client()

    def test_valid_submission_uses_parameterized_insert(self):
        response = self.client.post("/contact", data={
            "name": "Student", "email": "student@example.com", "message": "Hello!"
        })
        self.assertEqual(response.status_code, 303)
        self.cursor.execute.assert_called_once_with(
            INSERT, ("Student", "student@example.com", "Hello!")
        )

    def test_invalid_submission_never_opens_database_connection(self):
        response = self.client.post("/contact", data={
            "name": "Student", "email": "wrong-email", "message": "Hello!"
        })
        self.assertEqual(response.status_code, 400)
        self.connect.assert_not_called()

    def test_health_readiness_checks_database(self):
        response = self.client.get("/health/ready")
        self.assertEqual(response.status_code, 200)
        self.cursor.execute.assert_called_once_with("SELECT 1")

    def test_database_failure_does_not_show_error_details(self):
        self.connect.side_effect = OSError("internal secret path")
        response = self.client.post("/contact", data={
            "name": "Student", "email": "student@example.com", "message": "Hello!"
        })
        self.assertEqual(response.status_code, 503)
        self.assertNotIn(b"internal secret path", response.data)


if __name__ == "__main__":
    unittest.main()
