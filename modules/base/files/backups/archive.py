#!/usr/bin/python3

import argparse
import datetime
import internetarchive

parser = argparse.ArgumentParser(description='Archives files to archive.org')
parser.add_argument('--name', dest='name', help='Wiki name')
parser.add_argument('--file', dest='file_name', help='File to upload')
args = parser.parse_args()

item = internetarchive.get_item(f'miraheze-wikibackups-{args.name}-{date.day}{date.month}{date.year}')
date = datetime.date.today()
# metadata
md = {'title': f'miraheze-wikibackups-{args.name}-{date.day}{date.month}{date.year}', 'mediatype': 'web', 'subject': 'miraheze;wikiteam', 'date': date}
# upload
item.upload(args.file, metadata=md)
