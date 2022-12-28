# NmkrVendingMachine
A (barebone) Cardano NFT vending machine built with a few bash scripts, using Nmkr.io for minting.

## Requirements
- A synced Cardano node. You can run either locally or (as in my case) in a Docker container using the official image.
- Execution rights on the cardano-cli command. I use a container and the user who execute the script is in the docker group.
- A few packages installed, like jq, curl, sed, awk and probably more.
- A blockfrost.io account and api key.
- Same for nmkr.io: you'll need an api key. Also, take note of the project ID for your NFT collection and the address where you should send ADA for refunding your balance, used by the Nmkt's "Mint and Send" feature.

If you also use a Docker container for cardano-node, mount a volume for the directory containing those scripts: while the scripts should be called from the host, cardano-cli will generate some files that those scripts need to access.

## How does it work?
The "vending.sh" script will take care of generating a Cardano verification key, signing key, and an address specific for your Cardano node. If you already have those, just copy them inside "data/payment.vkey", "data/payment.skey", "data/payment.addr".

Every time vending.sh gets called, it will check for incoming transactions on that address. Once a new transaction is detected, the script will check if the "customer" is allowed to mint a NFT by execting a another script: "utils/canMint.sh".
I need that for my specific project, where I need to check the staking address of the customer to allow only a single mint per epoch. In this repository, it always return "true". You can either adapt it to your specific needs or edit vending.sh to get rid of it completely.


If the received amount is what you specified in the configuration file, two scripts get called:
- profit.sh
- mintAndSend.sh

The first script will take the received amount and create a new transaction, splitting it for both your "profit" address and the Nmkr.io address used to fill-up your balance for the "Mint and Send" feature.

The second script should take care of generating both the art for your NFT and the payload that will be sent to Nmkr for the real minting process. How to generate the art really depends on your needs, and I'm not including an example: this software is not provided as a "ready to go" solution, but as an example on how to implement a feature that it is not directly available with other tooling.

If for any reason the customer is not allowed to mint a NFT or if the received amount is incorrect, "refund.sh" will take care to send it back, minus the transaction fee.

## Getting started
Execute "vending.sh" once. It will generate a "config" file that you need to edit and provide your keys, prices, addresses, etc.

Execute it again to see if everything runs correctly. You'll find a vending.log file inside the "logs" directory, and new files in "data". If it's ok, you can run it in a cron job, depending on your needs.

Edit utils/canMint.sh and mintAndSend.sh so that they do what you are asking for.

