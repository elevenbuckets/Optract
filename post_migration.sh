#!/bin/sh

cp build/contracts/Optract.json build/contracts/OptractRegistry.json build/contracts/ERC20.json ./dapps/Optract/ABI && \
     cd dapps/Optract/ABI && \
     jq -r '.abi' Optract.json > Optract.abi && \
     jq -r '.abi' OptractRegistry.json > OptractRegistry.abi && \
     jq -r '.abi' ERC20.json > ERC20.abi

echo "# copy artifact and abi to dapps directory"
