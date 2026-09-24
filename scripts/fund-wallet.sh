#!/bin/bash
# scripts/fund-wallet.sh
set -e

if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

RPC=http://127.0.0.1:8545
POOL=0x011f31D20C8778c8Beb1093b73E3A5690Ee6271b
USDC=0xaf88d065e77c8cC2239327C5EDb3A432268e5831
ARB=0x912CE59144191C1204E64559FE8253a0e49E6548
ETH_AMOUNT=0xde0b6b3a7640000        # 1 ether
POOL_GAS_AMOUNT=0x2386f26fc10000   # 0.01 ether — solo para pagar gas

if [ -z "$TARGET_WALLET" ]; then
  echo "Error: TARGET_WALLET no está definido (ni en el entorno ni en .env)"
  exit 1
fi

echo "Fondeando $TARGET_WALLET..."

cast rpc anvil_setBalance $TARGET_WALLET $ETH_AMOUNT --rpc-url $RPC > /dev/null
echo "  ETH nativo: 1 (balance fijado, no acumulado)"

# Dale ETH al pool para que pueda pagar el gas de sus propias transferencias
cast rpc anvil_setBalance $POOL $POOL_GAS_AMOUNT --rpc-url $RPC > /dev/null

cast rpc anvil_impersonateAccount $POOL --rpc-url $RPC > /dev/null

cast send $USDC "transfer(address,uint256)" $TARGET_WALLET 100000000 \
  --from $POOL --unlocked --rpc-url $RPC > /dev/null
echo "  USDC transferido: 100"

cast send $ARB "transfer(address,uint256)" $TARGET_WALLET 50000000000000000000 \
  --from $POOL --unlocked --rpc-url $RPC > /dev/null
echo "  ARB transferido: 50"

echo "Resincronizando reservas del pool..."
cast send $POOL "sync()" --from $POOL --unlocked --rpc-url $RPC > /dev/null

cast rpc anvil_stopImpersonatingAccount $POOL --rpc-url $RPC > /dev/null

echo ""
echo "Balances finales:"
echo "  ETH:  $(cast balance $TARGET_WALLET --rpc-url $RPC --ether) ETH"
echo "  USDC: $(cast call $USDC "balanceOf(address)(uint256)" $TARGET_WALLET --rpc-url $RPC)"
echo "  ARB:  $(cast call $ARB "balanceOf(address)(uint256)" $TARGET_WALLET --rpc-url $RPC)"