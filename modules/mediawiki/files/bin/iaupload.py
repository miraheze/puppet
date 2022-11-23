#! /usr/bin/python3

import argparse
import internetarchive
import os

from datetime import datetime

# set HTTP proxy to use for getting the item from archive.org
# we then also set the session proxy for the item to use for uploading
# but we can't get the item to set session proxy without also setting HTTP_PROXY here
os.environ['HTTP_PROXY'] = 'http://bast.miraheze.org:8080'
os.environ['HTTPS_PROXY'] = 'http://bast.miraheze.org:8080'

# add arguments
parser = argparse.ArgumentParser(
    description='Uploads a file to archive.org.')
parser.add_argument(
    '--title', dest='title', required=True,
    help='The title of the file to be used on archive.org. Will be both the title and identifier. Required.')
parser.add_argument(
    '--description', dest='description', default='',
    help='The description of the file to be used on archive.org. Optional. Default: empty')
parser.add_argument(
    '--mediatype', dest='mediatype', default='web',
    help='The media type of the file to be used on archive.org. Optional. Default: web')
parser.add_argument(
    '--subject', dest='subject', default='miraheze;wikiteam',
    help='Subject (topics) of the file for archive.org. Multiple topics can be separated by a semicolon. Optional. Default: miraheze;wikiteam')
parser.add_argument(
    '--file', dest='file', required=True,
    help='The local path to the file to be uploaded to archive.org. Required.')
args = parser.parse_args()

item = internetarchive.get_item(args.title)

# set session proxy for uploading
item.session.proxies = {
    'http': 'http://bast.miraheze.org:8080',
    'https': 'http://bast.miraheze.org:8080',
}

# get last modification time from file to use as the publication date in archive.org
mtime = os.path.getmtime(args.file)
dt = datetime.fromtimestamp(mtime)
date = datetime.strftime(dt, '%Y-%m-%d')

# set metadata
# see https://archive.org/developers/metadata-schema for valid options
md = {
    'title': args.title,
    'description': args.description,
    'mediatype': args.mediatype,
    'subject': args.subject,
    'date': date,
}

# actually upload the file
item.upload(args.file, metadata=md)
