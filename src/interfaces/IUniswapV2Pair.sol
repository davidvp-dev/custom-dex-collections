// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

/**
 * @title Uniswap V2 pair interface
 * @notice Exposes token addresses and reserves for a liquidity pair.
 */
interface IUniswapV2Pair {
    /** @notice Returns the address of the first token in the pair. */
    function token0() external view returns (address);

    /** @notice Returns the address of the second token in the pair. */
    function token1() external view returns (address);

    /**
     * @notice Returns the pair reserves in token order and the last reserve update timestamp.
     * @return reserve0 Reserve of `token0`.
     * @return reserve1 Reserve of `token1`.
     * @return blockTimestampLast Timestamp of the last reserve update.
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
