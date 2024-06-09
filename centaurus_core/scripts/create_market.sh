#!/bin/bash

read -p "Import the env name (default: testnet): " env_name
read -p "Import gas budget (default: 1000000000): " gas_budget
read -p "Import wrapped coin name: " wrapped_coin
read -p "Import coin name: " coin


if [ -z "$gas_budget" ]; then
       gas_budget=1000000000
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
else
       echo "Running on non-MacOS"
       config="/root/.sui/sui_config/$env_name-client.yaml"
fi

package=`cat $deployments | jq -r ".centaurus_core.package"`
admin_cap=`cat $deployments | jq -r ".centaurus_core.admin_cap"`
market=`cat $deployments | jq -r ".centaurus_core.market"`
wrapped_coin_module=`cat $deployments | jq -r ".coins.$wrapped_coin.module"`
wrapped_coin_metadata=`cat $deployments | jq -r ".coins.$wrapped_coin.metadata"`
wrapped_coin_treasury=`cat $deployments | jq -r ".coins.$wrapped_coin.treasury"`
coin_module=`cat $deployments | jq -r ".coins.$coin.module"`
coin_metadata=`cat $deployments | jq -r ".coins.$coin.metadata"`
coin_treasury=`cat $deployments | jq -r ".coins.$coin.treasury"`

# add new vault
add_log=`sui client --client.config $config \
       call --gas-budget $gas_budget \
              --package $package \
              --module market \
              --function create_market \
              --type-args ${wrapped_coin_module} ${coin_module} \
              --args ${admin_cap} \
                     ${wrapped_coin_treasury}`
# Generate a date timestamp
date_suffix=$(date +"%Y%m%d_%H%M%S")

# Save add vault logs in log file
echo "$add_log" > ./logs/create_market_$date_suffix.log

ok=`echo "$add_log" | grep "Status: Success"`
