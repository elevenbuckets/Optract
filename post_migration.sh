#!/bin/sh

cp build/contracts/Optract.json build/contracts/OptractRegistry.json ./dapps/Optract/ABI && \
     cd dapps/Optract/ABI && \
     jq -r '.abi' Optract.json > Optract.abi && \
     jq -r '.abi' OptractRegistry.json > OptractRegistry.abi

echo "# copy artifact and abi to dapps directory"
