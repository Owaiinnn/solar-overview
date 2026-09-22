"""Checks for credential redaction and the smoke-test's data handling."""

import contextlib
import io
import json
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

import check_solaredge as check


class CheckTests(unittest.TestCase):
    def test_network_error_does_not_expose_credential_url(self):
        with patch.object(check, 'build_opener') as opener:
            opener.return_value.open.side_effect = URLError('https://example.test/?api_key=SECRET')
            with self.assertRaises(check.CheckError) as error:
                check.fetch('123', 'SECRET', 'overview')
            self.assertNotIn('SECRET', str(error.exception))

    def test_http_error_does_not_expose_response_or_url(self):
        with patch.object(check, 'build_opener') as opener:
            opener.return_value.open.side_effect = HTTPError(
                'https://example.test/?api_key=SECRET', 403, 'SECRET', {}, None)
            with self.assertRaises(check.CheckError) as error:
                check.fetch('123', 'SECRET', 'overview')
            self.assertIn('403', str(error.exception))
            self.assertNotIn('SECRET', str(error.exception))

    def test_redirect_is_not_followed(self):
        self.assertIsNone(check.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://example.test'))

    def test_overview_and_history_keep_missing_data_distinct(self):
        fixtures = [
            {'overview': {'lastUpdateTime': '2026-09-22 10:00:00',
                          'currentPower': {'power': 1200}, 'lastDayData': {'energy': 3500}}},
            {'power': {'unit': 'W', 'values': [{'value': 0}, {'value': None}, {'value': 1200}]}},
            {'siteCurrentPowerFlow': {'PV': {'currentPower': 1.2}}},
        ]
        stdout = io.StringIO()
        credentials = io.StringIO(json.dumps({'site_id': '123', 'api_key': 'a' * 32}))
        with patch('sys.argv', ['check', '--credentials-stdin']), patch('sys.stdin', credentials), \
                patch.object(check, 'fetch', side_effect=fixtures), contextlib.redirect_stdout(stdout):
            self.assertEqual(check.main(), 0)
        self.assertIn('1200 W', stdout.getvalue())
        self.assertIn('3500 Wh', stdout.getvalue())
        self.assertIn('2 measured points; 1 missing/non-numeric points', stdout.getvalue())
        self.assertIn('LOAD power field: unavailable', stdout.getvalue())


if __name__ == '__main__':
    unittest.main()
