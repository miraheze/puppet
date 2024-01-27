import unittest
from unittest.mock import patch
from datetime import datetime, timedelta
from renewssl import (
    SSLRenewer,
    days_until_expiry,
    get_cert_expiry_date,
    get_secondary_domains,
    should_renew,
)


class TestSSLRenewer(unittest.TestCase):
    def setUp(self):
        self.ssl_renewer = SSLRenewer('/etc/letsencrypt/live', 7, False, True)
        self.today = datetime.now()
        self.expiry_date = self.today + timedelta(days=30)

    @patch('subprocess.check_output')
    def test_should_renew_with_days_left(self, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        self.assertTrue(should_renew('test.com', 7, 14, False, True))

    @patch('subprocess.check_output')
    def test_should_renew_with_only_days(self, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        self.assertFalse(should_renew('test.com', 14, 7, True, True))

    @patch('subprocess.check_output')
    def test_should_renew_with_wildcard_domain(self, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=*.test.com
                X509v3 Subject Alternative Name:
                    DNS:*.test.com
            """
        mock_check_output.return_value = mock_output
        self.assertFalse(should_renew('*.test.com', 7, 14, False, True))

    @patch('subprocess.check_output')
    def test_should_renew_with_wildcard_secondary_domain(self, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com, DNS:www.test.com, DNS:*.test.com
            """
        mock_check_output.return_value = mock_output
        self.assertFalse(should_renew('test.com', 7, 14, False, True))

    @patch('subprocess.check_output')
    @patch('builtins.input')
    def test_should_renew_with_confirmation(self, mock_input, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        mock_input.return_value = 'y'
        self.assertTrue(should_renew('test.com', 7, None, False, False))

    @patch('subprocess.check_output')
    @patch('builtins.input')
    def test_should_not_renew_with_confirmation(self, mock_input, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        mock_input.return_value = 'n'
        self.assertFalse(should_renew('test.com', 7, None, False, False))

    @patch('renewssl.get_cert_expiry_date')
    @patch('renewssl.get_ssl_domains')
    @patch('subprocess.check_output')
    @patch('subprocess.call')
    def test_run_renews_certificate(self, mock_call, mock_check_output, mock_get_ssl_domains, mock_get_cert_expiry_date):
        self.ssl_renewer.only_days = True
        expiry_date = self.today + timedelta(days=5)
        expiry_date = f'{expiry_date.strftime("%b %d %H:%M:%S %Y")} GMT'
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        mock_get_ssl_domains.return_value = ['test.com']
        mock_get_cert_expiry_date.return_value = datetime.strptime(expiry_date, '%b %d %H:%M:%S %Y %Z')
        self.ssl_renewer.run()
        mock_call.assert_called_with(['sudo', '/root/ssl-certificate', '--domain', 'test.com', '--renew', '--private', '--overwrite'])

    @patch('renewssl.get_cert_expiry_date')
    @patch('renewssl.get_ssl_domains')
    @patch('subprocess.check_output')
    @patch('subprocess.call')
    def test_run_does_not_renew_certificate(self, mock_call, mock_check_output, mock_get_ssl_domains, mock_get_cert_expiry_date):
        self.ssl_renewer.only_days = True
        expiry_date = self.today + timedelta(days=10)
        expiry_date = f'{expiry_date.strftime("%b %d %H:%M:%S %Y")} GMT'
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com
            """
        mock_check_output.return_value = mock_output
        mock_get_ssl_domains.return_value = ['test.com']
        mock_get_cert_expiry_date.return_value = datetime.strptime(expiry_date, '%b %d %H:%M:%S %Y %Z')
        self.ssl_renewer.run()
        mock_call.assert_not_called()

    def test_days_until_expiry(self):
        self.assertEqual(days_until_expiry(self.expiry_date), 30)

    @patch('subprocess.check_output')
    def test_get_secondary_domains(self, mock_check_output):
        mock_output = b"""
            Certificate:
                Subject: CN=test.com
                X509v3 Subject Alternative Name:
                    DNS:test.com, DNS:www.test.com, DNS:subdomain.test.com
            """
        mock_check_output.return_value = mock_output
        self.assertEqual(get_secondary_domains('/etc/letsencrypt/live', 'test.com'), ['www.test.com', 'subdomain.test.com'])

    @patch('subprocess.check_output')
    def test_get_cert_expiry_date(self, mock_check_output):
        expiry_date = f'{self.expiry_date.strftime("%b %d %H:%M:%S %Y")} GMT'
        mock_check_output.return_value = f'notAfter={expiry_date}'.encode('utf-8')
        self.assertEqual(get_cert_expiry_date('test.com'), datetime.strptime(expiry_date, '%b %d %H:%M:%S %Y %Z'))
