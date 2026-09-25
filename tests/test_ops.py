# tests/test_ops.py - tests for the endpoints added for containerization

import unittest
from app import app


class TestOpsRoutes(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_health_route(self):
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {'status': 'ok'})

    def test_version_route(self):
        response = self.app.get('/version')
        self.assertEqual(response.status_code, 200)
        body = response.get_json()
        self.assertIn('version', body)
        self.assertIn('hostname', body)


if __name__ == '__main__':
    unittest.main()
