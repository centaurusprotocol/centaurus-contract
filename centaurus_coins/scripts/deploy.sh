#!/bin/bash

read -p "Import the env name (default: testnet): " env_name
read -p "Import gas budget (default: 1000000000): " gas_budget
read -p "Import the coin name: " coin

coin=$(echo $coin | tr 'A-Z' 'a-z')
coin_upper=$(echo $coin | tr 'a-z' 'A-Z')

if [ -z "$gas_budget" ]; then
  gas_budget="1000000000"
fi
if [ -z "$env_name" ]; then
  env_name="testnet"
fi
deployments="../../deployments-$env_name.json"
platform=$(uname)
user_name=$(id -un)

if [ "$platform" == "Darwin" ]; then
  echo "Running on MacOS"
  config="/Users/$user_name/.sui/sui_config/$env_name-client.yaml"
  # update Move.toml
  sed -i '' -e "s/\($coin\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"0x0\"/" ../$coin/Move.toml
else
  echo "Running on non-MacOS"
  config="/root/.sui/sui_config/$env_name-client.yaml"
  # update Move.toml
  sed -i "s/\($coin\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"0x0\"/" ../$coin/Move.toml
fi

# Generate a date timestamp
date_suffix=$(date +"%Y%m%d_%H%M%S")

# deploy
log=$(sui client --client.config $config publish ../$coin --skip-dependency-verification --gas-budget $gas_budget)
echo "$log" > ./logs/deploy_$date_suffix.log

ok=$(echo "$log" | grep "Status: Success")
if [ -n "$ok" ]; then
  # TODO: following replacement logic does not work, please manually override
  package=$(echo "$log" | grep '"type": String("published")' -A 1 | grep packageId | awk -F 'String\\("' '{print $2}' | awk -F '"\\)' '{print $1}')

  if [ "$platform" == "Darwin" ]; then
    # update Move.toml
    # modify field "$coin" to $package in Move.toml
    sed -i '' -e "s/\($coin\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"$package\"/" ../$coin/Move.toml
    # modify field "published-at" to $package in Move.toml
    sed -i '' -e "s/\(published-at\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"$package\"/" ../$coin/Move.toml
  else
    # update Move.toml
    # modify field "$coin" to $package in Move.toml
    sed -i "s/\($coin\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"$package\"/" ../$coin/Move.toml
    # modify field "published-at" to $package in Move.toml
    sed -i "s/\(published-at\s*=\s*\)\"0x[0-9a-fA-F]\+\"/\1\"$package\"/" ../$coin/Move.toml
  fi

  # modify field ".coins.$coin.module" in $deployments
  json_content=$(jq ".coins.$coin.module = \"$package::$coin::${coin_upper}\"" $deployments)

  metadata=$(echo "$log" | grep "0x2::coin::CoinMetadata<$package::$coin::${coin_upper}>" -A 1 | grep objectId | awk -F 'String\\("' '{print $2}' | awk -F '"\\)' '{print $1}')
  # modify field ".coins.$coin.metadata" in $deployments
  json_content=$(echo "$json_content" | jq ".coins.$coin.metadata = \"$metadata\"")

  treasury=`echo "$log" | grep "0x2::coin::TreasuryCap<$package::$coin::${coin_upper}>" -A 1 | grep objectId | awk -F 'String\\("' '{print $2}' | awk -F '"\\)' '{print $1}'`
  # modify field ".coins.$coin.treasury" in $deployments
  json_content=`echo "$json_content" | jq ".coins.$coin.treasury = \"$treasury\""`

  if [ -n "$json_content" ]; then
    echo "$json_content" | jq . >$deployments
    echo "Update $deployments finished!"
  else
    echo "Update $deployments failed!"
  fi
fi
