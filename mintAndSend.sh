#!/bin/bash
#
# Mint a NFT and send it to the specified address.
# Keep this file next to "vending.sh".
#

if [ $# -ne 2 ]
then
  echo "Usage: $( basename $0 ) <stake-address> <send-address>"
  exit 1
fi

if [ ! -f "config" ]
then
  echo "Error: cannot find a config file"
  exit 2
fi

. config

# A script that creates the image and a mint request file for nmkr
./utils/generate.sh

if [ ! -f "mintRequest" ]
then
  echo "Error: cannot find a mintRequest file"
  exit 2
fi

curl -H "Authorization: Bearer $nmkrKey" -H 'Content-Type: application/json' https://studio-api.nmkr.io/v2/UploadNft/$nmkrProjectUid -d "$(cat mintRequest)" > mintResult

sleep 10s

nftUid=$( cat mintResult | jq -r .nftUid )
if [ "$nftUid" == "null" ]
then
  echo "Error: no nftUid found in the mintResult file"
  exit 2
fi

curl -H "Authorization: Bearer $nmkrKey" https://studio-api.nmkr.io/v2/MintAndSendSpecific/$nmkrProjectUid/$nftUid/1/$2

rm -f mintRequest mintResult

