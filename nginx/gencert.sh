#!/bin/bash

# TODO Use https://github.com/FiloSottile/mkcert

# See https://betterprogramming.pub/how-to-create-trusted-ssl-certificates-for-your-local-development-13fd5aad29c6

if [[ $1 == "" ]]
then
    printf "Please provide a virtual host name.\n";
    exit 1
fi

if [[ $1 == "ca" ]]
then
    printf "'ca' is reserved.\n";
    exit 1
fi

# Generate CA if it does not exist
if [[ ! -f '/etc/nginx/certs/ca.key' ]] \
    || [[ ! -f '/etc/nginx/certs/ca.pem' ]] \
    || [[ ! -f '/etc/nginx/certs/ca.crt' ]]
then
    openssl req -x509 -nodes \
        -new -sha512 \
        -days 3650 \
        -subj "/C=FR/CN=LOCAL-CA" \
        -newkey rsa:4096 \
        -keyout /etc/nginx/certs/ca.key \
        -out /etc/nginx/certs/ca.pem

    openssl x509 -outform pem \
        -in /etc/nginx/certs/ca.pem \
        -out /etc/nginx/certs/ca.crt

    chown nginx:nginx \
        /etc/nginx/certs/ca.key \
        /etc/nginx/certs/ca.pem \
        /etc/nginx/certs/ca.crt \
        /etc/nginx/certs/ca.srl
fi

if [[ -f "/etc/nginx/certs/$1.key" ]]
then
    rm "/etc/nginx/certs/$1.key"
fi
if [[ -f "/etc/nginx/certs/$1.csr" ]]
then
    rm "/etc/nginx/certs/$1.csr"
fi
if [[ -f "/etc/nginx/certs/$1.crt" ]]
then
    rm "/etc/nginx/certs/$1.crt"
fi

echo "authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
# Local hosts
DNS.1 = localhost
DNS.2 = 127.0.0.1
DNS.3 = ::1
# List your domain names here
DNS.4 = $1
" > v3.ext

openssl req -new -nodes -newkey rsa:4096 \
  -keyout "/etc/nginx/certs/$1.key" \
  -out "/etc/nginx/certs/$1.csr" \
  -subj "/C=FR/O=Company/CN=$1"

openssl x509 -req -sha512 -days 3650 \
  -extfile v3.ext \
  -CA /etc/nginx/certs/ca.crt \
  -CAkey /etc/nginx/certs/ca.key \
  -CAcreateserial \
  -in "/etc/nginx/certs/$1.csr" \
  -out "/etc/nginx/certs/$1.crt"

rm v3.ext

chown nginx:nginx \
    "/etc/nginx/certs/$1.key" \
    "/etc/nginx/certs/$1.crt" \
    "/etc/nginx/certs/$1.csr"

printf "Done !\n"

exit 0
