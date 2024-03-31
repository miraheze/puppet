#!/bin/bash

# HELP: to run the script (make sure to ):
# ./generate-admin-certificate.sh <path to store files, e.g. /root)>
#  copy contents of wikitide-ca.pem
# To convert ca file from crt to pem you do (this script already creates the ca in pem format but useful for converting LetsEncrypt):
# openssl x509 -in <ca>.crt -out <ca>.pem -outform PEM
# to convert private key from rsa to PKCS8:
# openssl pkcs8 -topk8 -in <old_key>.crt -out <new_key>.pem -nocrypt
CN=ADMIN_WIKITIDE,O=WikiTide Foundation,L=Washington,ST=DC,C=US
openssl genrsa -out $1/wikitide-ca-key.pem 2048
openssl req -new -x509 -sha256 -key $1/wikitide-ca-key.pem -subj "/C=US/ST=DC/L=Washington/O=WikiTide Foundation" -out $1/wikitide-ca.pem -days 730

openssl genrsa -out $1/admin-key-temp.pem 2048
openssl pkcs8 -inform PEM -outform PEM -in $1/admin-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out $1/admin-key.pem
openssl req -new -key $1/admin-key.pem -subj "/C=US/ST=DC/L=Washington/O=WikiTide Foundation/CN=ADMIN_WIKITIDE" -out $1/admin.csr
openssl x509 -req -in $1/admin.csr -CA $1/wikitide-ca.pem -CAkey $1/wikitide-ca-key.pem -CAcreateserial -sha256 -out $1/admin.pem -days 730
