#!/bin/bash

set -o errexit
set -o pipefail

# Create local files
rm -rf files && mkdir -p files
echo "Call for Papers management" > "files/file_cfp.txt"
echo "ACME Document" > "files/file_acme.txt"
echo "Presentation management" > "files/file_conf.txt"

FOLDER_ID=$(./alfresco node create -n folder -i -shared- -t cm:folder -o id)

# Upload local files to Repository
./alfresco node create -n file_cfp.txt -i $FOLDER_ID -t cfp:proposal -f $PWD/files/file_cfp.txt -o id >> /dev/null
./alfresco node create -n file_acme.txt -i $FOLDER_ID -t acme:document -f $PWD/files/file_acme.txt -o id >> /dev/null
./alfresco node create -n file_conf.txt -i $FOLDER_ID -t conf:Presentation -f $PWD/files/file_conf.txt -o id >> /dev/null