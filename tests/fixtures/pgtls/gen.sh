#!/bin/sh
# Regenerate the TLS fixtures tests/test_sql_postgres.ae uses: a test CA and
# a server certificate for localhost / 127.0.0.1 signed by it, EC P-256,
# valid for 20 years. Test-only keys: never trust this CA anywhere else.
set -eu
cd "$(dirname "$0")"
openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -x509 -new -key ca.key -sha256 -days 7300 -subj "/CN=testcontainers-ae test CA" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" -out ca.crt
openssl ecparam -name prime256v1 -genkey -noout -out server.key
openssl req -new -key server.key -subj "/CN=localhost" -out server.csr
printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost,IP:127.0.0.1\n' > server.ext
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -days 7300 -sha256 -extfile server.ext -out server.crt
rm -f server.csr server.ext ca.srl ca.key
