#!/bin/bash

if [[ $1 == "" ]]
then
    printf "Please provide a virtual host name.\n";
    exit
fi

cd /etc/nginx/certs

openssl genrsa -des3 -passout pass:x -out $1.pass.key 2048
openssl rsa -passin pass:x -in $1.pass.key -out $1.key
rm $1.pass.key

openssl req -new -key $1.key -out $1.csr -subj "/C=FR/O=$1/OU=$1/CN=$1"
openssl x509 -req -sha256 -days 300065 -in $1.csr -signkey $1.key -out $1.crt
rm $1.csr

chown nginx:nginx $1.key $1.crt

printf "Done !\n"
