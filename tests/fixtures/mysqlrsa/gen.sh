#!/bin/sh
# Regenerate the RSA key pair tests/test_sql_mysql_unit.ae uses to check
# sql/mysql's RSA-OAEP (SHA-1) password encryption: the public key encrypts
# as a MySQL server's would be used, the private key (PKCS#1) decrypts again.
# Test-only key: never use it anywhere else.
set -eu
cd "$(dirname "$0")"
openssl genrsa -traditional -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem
