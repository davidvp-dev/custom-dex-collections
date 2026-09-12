// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

/**
 * @title Uniswap V2 factory interface
 * @notice Exposes pair lookup for two token addresses.
 */
interface IUniswapV2Factory {
    /**
     * @notice Returns the pair created for two tokens.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @return pair Address of the pair, or the zero address if it does not exist.
     */
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
