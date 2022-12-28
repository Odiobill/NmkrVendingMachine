#!/bin/bash
#
# Vending Machine for Cardano, using nmkr.io for minting the NFTs.
#

exePath=$(realpath "${BASH_SOURCE:-$0}")
exePath=$(dirname "$exePath")

# configFile should be in the same directory containing this script
configFile="${exePath}/config"

cfgPath=$(dirname "$configFile")
if [ ! -f "$configFile" ]
then
  scriptName=$(basename "$0")
  echo "# WARNING: Please double-check carefully all the following variables and" >> $configFile
  echo "# replace their values according to your specific needs. You are solely" >> $configFile
  echo "# responsible for any funds lost or sent to the wrong address." >> $configFile
  echo "" >> $configFile
  echo "# Your Blockfrost.io key" >> $configFile
  echo "blockfrostKey=BLOCKFROST_KEY" >> $configFile
  echo "" >> $configFile
  echo "# Your nmkr.io api key" >> $configFile
  echo "nmkrKey=NMKR_KEY" >> $configFile
  echo "" >> $configFile
  echo "# Your nmkr project uid" >> $configFile
  echo "nmkrProjectUid=NMKR_PROJECT" >> $configFile
  echo "" >> $configFile
  echo "# nmkr.io address to refill your minting budget" >> $configFile
  echo "nmkrAddr=addr1v96mljd2ctmuw4e0vjdsmfs7jayhrt2cylm9xk0e33ms24snxk38f" >> $configFile
  echo "" >> $configFile
  echo "# Where to send your profits" >> $configFile
  echo "profitAddr=addr1q9vef9smnp4kfjcglr3q74wcqncn42zz3sz8kc2l0n8ar9n2psx54pfg7d3pkqmp4c0teu5kzeml07gllant5l8mstcqlkxtm7" >> $configFile
  echo "" >> $configFile
  echo "# The mint price of NFTs, in Lovelaces" >> $configFile
  echo "mintPrice=10000000" >> $configFile
  echo "" >> $configFile
  echo "# The amount that will be sent to nmkr.io to refill your minting budget, in Lovelaces" >> $configFile
  echo "nmkrAmount=4206969" >> $configFile
  echo "" >> $configFile
  echo "# If you run \"cardano-node\" from a container, give it a volume for the" >> $configFile
  echo "# directory containing the \"$scriptName\" file, and set the following" >> $configFile
  echo "# variable, \"vendingPath\", to the path of the volume FROM the" >> $configFile
  echo "# \"cardano-node\" container. If not, set it to the same directory" >> $configFile
  echo "# which cointains \"$scriptName\"." >> $configFile
  echo "vendingPath=/rookiez-nft" >> $configFile
  echo "" >> $configFile
  echo "# If you DON'T run \"cardano-node\" from a container, set the following" >> $configFile
  echo "# variable, cardanoCliCommand, to the location of \"cardano-cli\".">> $configFile
  echo "cardanoCliCommand=\"docker exec -ti cardano-node cardano-cli\"" >> $configFile
  echo "" >> $configFile
fi

. "$configFile"
if [ "$blockfrostKey" == "BLOCKFROST_KEY" -o "$nmkrKey" == "NMKR_KEY" -o "$nmkrProjectUid" == "NMKR_PROJECT" ]
then
  echo "Please edit \"$configFile\" accordingly."
  exit 1
fi

paymentSkey="data/payment.skey"
paymentVkey="data/payment.vkey"
paymentAddr="data/payment.addr"
protocolJson="data/protocol.json"
completedTxs="data/completed"
logFile="logs/vending.log"
tmpUtxos="tmp/utxos"

cd "$cfgPath"
mkdir -p $(dirname "$completedTxs") $(dirname "$logFile") $(dirname "$tmpUtxos")

if [ ! -f "$completedTxs" ]
then
  touch "$completedTxs"
fi

if [ ! -f "$paymentSkey" ]
then
  $cardanoCliCommand address key-gen --verification-key-file "${vendingPath}/${paymentVkey}" --signing-key-file "${vendingPath}/${paymentSkey}"
  $cardanoCliCommand address build --payment-verification-key-file "${vendingPath}/${paymentVkey}" --out-file "${vendingPath}/${paymentAddr}" --mainnet
  echo "New keys and payment address generated." >> $logFile
fi

cat ${paymentAddr} >/dev/null 2>&1
if [ $? -ne 0 ]
then
  echo "Check permissions for \"${cfgPath}/${paymentAddr}\" and try again."
  exit 2
fi

if [ ! -f "${protocolJson}" ]
then
  echo "Downloading protocol parameters..." >> $logFile
  $cardanoCliCommand query protocol-parameters --mainnet --out-file=${vendingPath}/${protocolJson}
fi

paymentAddr=$(cat ${paymentAddr})

rm -f "$tmpUtxos"
touch "$tmpUtxos"
$cardanoCliCommand query utxo --address $paymentAddr --mainnet | tail -n +3 | sort -k3 -nr | while read utxo
do
  utxos=$(cat "$tmpUtxos")
  txHash=$(awk '{ print $1 }' <<< "${utxo}")
  txIx=$(awk '{ print $2 }' <<< "${utxo}")
  balance=$(awk '{ print $3 }' <<< "${utxo}")

  utxos="$utxos ${txHash},${txIx},${balance}"
  echo "$utxos" | sed "s/^ //" > "$tmpUtxos"
done

utxos=$(cat "$tmpUtxos")
for utxo in "$utxos"
do
  txHash=$(awk -F ',' '{ print $1 }' <<< "${utxo}")
  txIx=$(awk -F ',' '{ print $2 }' <<< "${utxo}")
  balance=$(awk -F ',' '{ print $3 }' <<< "${utxo}")

  if [ ${#txHash} -eq 0 -a ${#txIx} -eq 0 -a ${#balance} -eq 0 ]
  then
    #echo "Nothing to do"
    exit 0
  fi

  if [ $( grep -q "${txHash}" "$completedTxs" && echo $? ) ]
  then
    #echo "$(date +%s) Skipping already processed transfer" >> $logFile
    touch $logFile
  else
    echo "$(date +%s) Received ${balance}" >> $logFile

    inAddr=$(curl -s -H "project_id: $blockfrostKey" \
      https://cardano-mainnet.blockfrost.io/api/v0/txs/${txHash}/utxos \
      | jq '.inputs' | jq '.[0]' | jq '.address' | sed 's/^.//;s/.$//')
    stakeAddr=$(curl -s -H "project_id: $blockfrostKey" \
      https://cardano-mainnet.blockfrost.io/api/v0/addresses/${inAddr} \
      | jq '.stake_address' | sed 's/^.//;s/.$//')

    ./utils/canMint.sh $stakeAddr $($cardanoCliCommand query tip --mainnet | jq .epoch)
    if [ $? -ne 0 -o ${balance} != "${mintPrice}" ]
    then
      echo "$(date +%s) Refunding ${inAddr}, stakeAddr ${stakeAddr}" >> $logFile
      ./refund.sh "$txHash" "$txIx" "$balance" "$inAddr"
    else
      echo "$(date +%s) Minting NFT..." >> $logFile
      ./profit.sh "$txHash" "$txIx" "$balance"
      ./mintAndSend.sh $stakeAddr $inAddr
    fi
    echo ${txHash} >> "$completedTxs"
  fi
done
exit 0

