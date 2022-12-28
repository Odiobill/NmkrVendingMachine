#!/bin/bash
#
# Check if the provided stake address is allowed to mint a NFT.
#

if [ $# -ne 2 ]
then
  echo "Usage: $( basename $0 ) <stake-address> <current-epoch>"
  exit 1
fi

exit 0

