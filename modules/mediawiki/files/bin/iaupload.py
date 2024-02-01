#! /usr/bin/python3

# Upload files to archive.org directly
# from the command line.
#
# Universal Omega 2022

import argparse
import internetarchive
import os
from datetime import datetime


class ArchiveUploader:
    def __init__(self):
        self.parser = argparse.ArgumentParser(
            description='Uploads a file to archive.org.')
        self.parser.add_argument(
            '--title', dest='title', required=True,
            help='The title of the file to be used on archive.org. Will be both the title and identifier. Required.')
        self.parser.add_argument(
            '--description', dest='description', default='',
            help='The description of the file to be used on archive.org. Optional. Default: empty')
        self.parser.add_argument(
            '--mediatype', dest='mediatype', default='web',
            help='The media type of the file to be used on archive.org. Optional. Default: web')
        self.parser.add_argument(
            '--subject', dest='subject', default='miraheze;wikiteam',
            help='Subject (topics) of the file for archive.org. Multiple topics can be separated by a semicolon. Optional. Default: miraheze;wikiteam')
        self.parser.add_argument(
            '--collection', dest='collection', default='opensource',
            help='The name of the collection to use on archive.org. Optional. Default: opensource')
        self.parser.add_argument(
            '--file', dest='file', required=True,
            help='The local path to the file to be uploaded to archive.org. Required.')
        self.parser.add_argument(
            '--proxy', dest='proxy', default='http://bastion.wikitide.net:8080',
            help='The proxy to use for requests to archive.org. Optional. Default: http://bastion.wikitide.net:8080')

    def upload(self):
        args = self.parser.parse_args()

        item = internetarchive.get_item(args.title)

        if args.proxy:
            # set HTTP proxy to use for getting the item from archive.org
            # we then also set the session proxy for the item to use for uploading
            # but we can't get the item to set session proxy without also setting HTTP_PROXY here
            os.environ['HTTP_PROXY'] = args.proxy
            os.environ['HTTPS_PROXY'] = args.proxy

            # set session proxy for uploading
            item.session.proxies = {
                'http': args.proxy,
                'https': args.proxy,
            }

        # get last modification time from file to use as the publication date in archive.org
        mtime = os.path.getmtime(args.file)
        dt = datetime.fromtimestamp(mtime)
        date = datetime.strftime(dt, '%Y-%m-%d')

        # set metadata
        # see https://archive.org/developers/metadata-schema for valid options
        md = {
            'collection': args.collection,
            'date': date,
            'description': args.description,
            'mediatype': args.mediatype,
            'subject': args.subject,
            'title': args.title,
        }

        # actually upload the file
        item.upload(args.file, metadata=md, verbose=True, queue_derive=False)


if __name__ == '__main__':
    uploader = ArchiveUploader()
    uploader.upload()
