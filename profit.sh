#!/bin/bash
#
# Sends parts of the received amount to nmkr.io (to fill up the minting budget), while the rest will got to the "profit" address.
# Keep this file next to "vending.sh".
#

if [ $# -ne 3 ]
then
  echo "Usage: $( basename $0 ) <tx-hash> <tx-ix> <balance>"
  exit 1
fi

if [ ! -f config" ]
then
  echo "Error: cannot find a config file"
  exit 2
fi

. config

txIn="--tx-in ${1}#${2}"
balance=$3

profitAmount=$(( ${balance}-${nmkrAmount} ))

currentSlot=$($cardanoCliCommand query tip --mainnet | jq -r '.slot')

$cardanoCliCommand transaction build-raw --fee 0 ${txIn} --tx-out ${profitAddr}+${profitAmount} --tx-out ${nmkrAddr}+${nmkrAmount} --invalid-hereafter $(( ${currentSlot} + 1000 )) --out-file "${vendingPath}/tmp/tx.tmp" 

fee=$($cardanoCliCommand transaction calculate-min-fee --tx-body-file "${vendingPath}/tmp/tx.tmp" --tx-in-count 1 --tx-out-count 2 --mainnet --witness-count 2 --byron-witness-count 0 --protocol-params-file "${vendingPath}/data/protocol.json" | awk '{ print $1 }')

amountToSendNmkr=$(( ${nmkrAmount}-${fee} ))
$cardanoCliCommand transaction build-raw --fee ${fee} ${txIn} --tx-out ${profitAddr}+${profitAmount} --tx-out ${nmkrAddr}+${amountToSendNmkr} --invalid-hereafter $(( ${currentSlot} + 1000 )) --out-file "${vendingPath}/tmp/tx.raw"

$cardanoCliCommand transaction sign --signing-key-file "${vendingPath}/data/payment.skey" --tx-body-file "${vendingPath}/tmp/tx.raw" --out-file "${vendingPath}/tmp/tx.signed" --mainnet

$cardanoCliCommand transaction submit --tx-file "${vendingPath}/tmp/tx.signed" --mainnet

