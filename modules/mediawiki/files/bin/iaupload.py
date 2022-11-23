#! /usr/bin/python3

import argparse
import datetime
import internetarchive
import os

os.environ['HTTP_PROXY'] = 'http://bast.miraheze.org:8080'
os.environ['HTTPS_PROXY'] = 'http://bast.miraheze.org:8080'

parser = argparse.ArgumentParser(
    description='Uploads file to archive.org.')
parser.add_argument(
    '--title', dest='title', required=True,
    help='Title of the file for archive.org.')
parser.add_argument(
    '--mediatype', dest='mediatype', default='web',
    help='Mediatype of the file for archive.org. Default: web')
parser.add_argument(
    '--subject', dest='mediatype', default='miraheze;wikiteam',
    help='Subjects the file for archive.org. Separated by semicolon. Default: miraheze;wikiteam')
args = parser.parse_args()
parser.add_argument(
    '--file', dest='file', required=True,
    help='Local path to file to be uploaded to archive.org.')

item = internetarchive.get_item(args.title)

# set session proxy
item.session.proxies = {
    'http': 'http://bast.miraheze.org:8080',
    'https': 'http://bast.miraheze.org:8080',
}

# get last modification time from file to use as date in archive.org
mtime = os.path.getmtime(args.file)
dt = datetime.fromtimestamp(mtime)
date = datetime.strptime(dt, '%Y-%m-%d')

# metadata
md = {
    'title': args.title,
    'mediatype': args.mediatype,
    'subject': args.subject,
    'date': date,
}

# upload
item.upload(args.file, metadata=md)
