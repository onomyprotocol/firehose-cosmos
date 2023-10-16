#!/usr/bin/env bash

###########################################################
# ToDo: Update settings for MAINNET, after mainnet Launch #
###########################################################
set -o errexit
set -o pipefail

CLEANUP=${CLEANUP:-"0"}
NETWORK=${NETWORK:-"mainnet"}
ONEX_HOME=${ONEX_HOME:-"$HOME/.onomy_onex"}
ONEX_VERSION=${ONEX_VERSION:-"v1.0.2-onex"}
ONEX_GENESIS_HEIGHT=${ONEX_GENESIS_HEIGHT:-"1"}

case $NETWORK in
  mainnet)
    echo "Using MAINNET"
    ONEX_GENESIS="https://raw.githubusercontent.com/onomyprotocol/multiverse/onex-testnet-3-genesis/genesis.json"
  ;;
  testnet)
    echo "Using TESTNET"
    ONEX_GENESIS="https://raw.githubusercontent.com/onomyprotocol/multiverse/onex-testnet-3-genesis/genesis.json"
  ;;
  *)
    echo "Invalid network: $NETWORK"; exit 1;
  ;;
esac


if [[ -z $(which "wget" || true) ]]; then
  echo "ERROR: wget is not installed"
  exit 1
fi

if [[ $CLEANUP -eq "1" ]]; then
  echo "Deleting all local data"
  rm -rf ./tmp/ > /dev/null
fi

echo "Setting up working directory"
mkdir -p tmp
pushd tmp

echo "Your platform is $OS_PLATFORM/$OS_ARCH"

# Install onexd binary if it doesn't exist
if [ ! -f "onexd" ]; then
  echo "Downloading onex $ONEX_VERSION binary"
    wget --quiet -O ./onomyd "https://github.com/onomyprotocol/onomy/releases/download/$ONEX_VERSION/onexd"
  chmod +x ./onomyd
fi


if [ ! -d $ONEX_HOME ]; then
  echo "Configuring home directory"
  ./onexd --home=$ONEX_HOME init $(hostname) 2> /dev/null
  rm -f \
    $ONEX_HOME/config/genesis.json \
    $ONEX_HOME/config/addrbook.json
fi

if [ ! -f "$ONEX_HOME/config/genesis.json" ]; then
  echo "Downloading genesis file"
  wget -O $ONEX_HOME/config/genesis.json $ONEX_GENESIS
fi

case $NETWORK in
  mainnet) # Setting up persistent peers
   echo "Configuring p2p seeds"
    sed -i -e 's/persistent_peers = ""//persistent_peers = "954c1b86d9a4ee0488be6abc57a0488a88d85fba@34.66.225.143:26657,e7ea2a55be91e35f5cf41febb60d903ed2d07fea@34.86.135.162:26657,2a40d447fe1aeaa666621906b26ad40089aa6a6c@180.131.222.73:26756,6eb9d594e39e2c9d089f9a8f1677e574f986e50a@64.71.153.55:26756"g' $ONEX_HOME/config/config.toml 
  ;;
  testnet) # Setting up persistent peers
    echo "Configuring p2p seeds"
    sed -i -e 's/persistent_peers = ""//persistent_peers = "954c1b86d9a4ee0488be6abc57a0488a88d85fba@34.66.225.143:26657,e7ea2a55be91e35f5cf41febb60d903ed2d07fea@34.86.135.162:26657,2a40d447fe1aeaa666621906b26ad40089aa6a6c@180.131.222.73:26756,6eb9d594e39e2c9d089f9a8f1677e574f986e50a@64.71.153.55:26756"g' $ONEX_HOME/config/config.toml
  ;;
esac

cat << END >> onex_home/config/config.toml

#######################################################
###       Extractor Configuration Options     ###
#######################################################
[extractor]
enabled = true
output_file = "stdout"
END

if [ ! -f "firehose.yml" ]; then
  cat << END >> firehose.yml
start:
  args:
    - reader
    - merger
    - firehose
  flags:
    common-first-streamable-block: $ONEX_GENESIS_HEIGHT
    common-live-blocks-addr:
    reader-mode: node
    reader-node-path: ./onexd
    reader-node-args: start --x-crisis-skip-assert-invariants --home=./onex_home
    reader-node-logs-filter: "module=(p2p|pex|consensus|x/bank)"
    relayer-max-source-latency: 99999h
    verbose: 1
END
fi
