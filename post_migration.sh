#!/bin/sh

cp build/contracts/Optract.json build/contracts/OptractRegistry.json build/contracts/DAI.json build/contracts/MemberShip.json build/contracts/BlockRegistry.json ./dapps/Optract/ABI && \
     cd dapps/Optract/ABI && \
     jq -r '.abi' Optract.json > Optract.abi && \
     jq -r '.abi' OptractRegistry.json > OptractRegistry.abi && \
     jq -r '.abi' DAI.json > DAI.abi && \
     jq -r '.abi' BlockRegistry.json > BlockRegistry.abi && \
     jq -r '.abi' MemberShip.json > MemberShip.abi

echo $?
echo "# copy artifact and abi to dapps directory"
