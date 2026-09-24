#!/bin/bash
# scripts/bootstrap-local.sh
# Levanta anvil, despliega CustomDEX y fondea tu wallet. Todo en un comando.
set -e

RPC=http://127.0.0.1:8545
ANVIL_PID_FILE=.anvil.pid

echo "Arrancando anvil (fork de Arbitrum Mainnet, chainId 1337)..."
anvil --fork-url https://arb1.arbitrum.io/rpc --chain-id 1337 > anvil.log 2>&1 &
echo $! > $ANVIL_PID_FILE

# Espera a que anvil esté listo antes de seguir
echo "Esperando a que anvil responda..."
until cast block-number --rpc-url $RPC > /dev/null 2>&1; do
  sleep 0.3
done
echo "anvil listo (PID $(cat $ANVIL_PID_FILE))."

echo "Desplegando CustomDEX..."
forge script script/DeployCustomDEX.s.sol --rpc-url $RPC --broadcast

echo "Fondeando wallet..."
./scripts/fund-wallet.sh

echo ""
echo "Entorno local listo. Para pararlo: kill \$(cat $ANVIL_PID_FILE)"