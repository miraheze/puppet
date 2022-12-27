#! /usr/bin/python3

"""
This script checks the current number of connections to a MySQL server and compares it to a maximum number of connections.
If the connection usage percentage exceeds a specified critical or warning threshold, a message is displayed and the script exits
with a corresponding exit status.

Created by Universal Omega
"""


import argparse
import mysql.connector

parser = argparse.ArgumentParser(description='MySQL connection usage check')

# Add the arguments
parser.add_argument('--host', required=True, help='MySQL host')
parser.add_argument('--user', required=True, help='MySQL user')
parser.add_argument('--password', required=True, help='MySQL password')
parser.add_argument('--max-connections', type=int, required=True, help='Max connections')
parser.add_argument('--critical-threshold', type=int, required=True, help='Critical threshold')
parser.add_argument('--warning-threshold', type=int, required=True, help='Warning threshold')
parser.add_argument('--ssl-key', help='SSL key file')
parser.add_argument('--ssl-cert', help='SSL certificate file')
parser.add_argument('--ssl-ca', help='SSL CA file')
parser.add_argument('--ssl-verify-server-cert', action='store_true', help='Verify server SSL certificate')

# Parse the command-line arguments
args = parser.parse_args()

# Connect to the MySQL server using SSL
conn = mysql.connector.connect(
    host=args.host,
    user=args.user,
    password=args.password,
    ssl_key=args.ssl_key,
    ssl_cert=args.ssl_cert,
    ssl_ca=args.ssl_ca,
    ssl_verify_server_cert=args.ssl_verify_server_cert
)

# Retrieve the current number of connections from the SHOW STATUS output
cursor = conn.cursor()
cursor.execute('SHOW STATUS WHERE Variable_name = "Threads_connected"')
row = cursor.fetchone()
current_connections = int(row[1])

# Calculate the connection usage percentage
connection_usage = current_connections / args.max_connections * 100

# Display a message and exit status based on the connection usage percentage
if connection_usage >= args.critical_threshold:
    print(f'Critical connection usage: {round(connection_usage, 2)}%')
    exit(2)
elif connection_usage >= args.warning_threshold:
    print(f'Warning connection usage: {round(connection_usage, 2)}%')
    exit(1)
else:
    print(f'OK connection usage: {round(connection_usage, 2)}%')
    exit(0)
