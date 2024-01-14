import unittest
import tempfile
import os
from datetime import datetime
from unittest.mock import MagicMock, patch
from iaupload import ArchiveUploader


class TestArchiveUploader(unittest.TestCase):
    def setUp(self):
        self.uploader = ArchiveUploader()

    def test_args(self):
        args = self.uploader.parser.parse_args([
            '--title', 'test_title',
            '--file', '/path/to/test_file',
            '--proxy', '',
        ])
        self.assertEqual(args.title, 'test_title')
        self.assertEqual(args.file, '/path/to/test_file')
        self.assertEqual(args.collection, 'opensource')
        self.assertEqual(args.description, '')
        self.assertEqual(args.mediatype, 'web')
        self.assertEqual(args.subject, 'miraheze;wikiteam')
        self.assertEqual(args.proxy, '')

    @patch('argparse.ArgumentParser.parse_args')
    @patch('internetarchive.get_item')
    def test_upload(self, mock_get_item, mock_parse_args):
        with tempfile.NamedTemporaryFile(delete=False) as f:
            f.write(b'test data')

        mock_item = MagicMock()
        mock_get_item.return_value = mock_item

        now = datetime.now()
        mtime = now.timestamp()
        os.utime(f.name, (mtime, mtime))
        mock_args = {
            'title': 'test_title',
            'file': f.name,
            'collection': 'opensource',
            'description': '',
            'mediatype': 'web',
            'subject': 'miraheze;wikiteam',
        }
        mock_parse_args.return_value = MagicMock(**mock_args)

        self.uploader.upload()

        mock_item.upload.assert_called_once_with(f.name, metadata={
            'collection': 'opensource',
            'date': now.strftime('%Y-%m-%d'),
            'description': '',
            'mediatype': 'web',
            'subject': 'miraheze;wikiteam',
            'title': 'test_title',
        }, verbose=True, queue_derive=False)

        os.remove(f.name)


if __name__ == '__main__':
    unittest.main()
