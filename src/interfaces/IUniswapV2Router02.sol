// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

/**
 * @title Uniswap V2 Router02 interface
 * @notice Defines the router operations used by the DEX and its frontend.
 */
interface IUniswapV2Router02 {
    /**
     * @notice Swaps an exact amount of input tokens for at least a minimum output amount.
     * @param amountIn Exact amount of input tokens.
     * @param amountOutMin Minimum acceptable amount of output tokens.
     * @param path Token path from input token to output token.
     * @param to Recipient of the output tokens.
     * @param deadline Unix timestamp after which the swap must not execute.
     * @return amounts Amount of tokens received at each step of the path.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @notice Adds token liquidity to a pair.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param amountADesired Desired amount of the first token.
     * @param amountBDesired Desired amount of the second token.
     * @param amountAMin Minimum amount of the first token to add.
     * @param amountBMin Minimum amount of the second token to add.
     * @param to Recipient of the LP tokens.
     * @param deadline Unix timestamp after which the operation must not execute.
     * @return amountA Actual amount of the first token added.
     * @return amountB Actual amount of the second token added.
     * @return liquidity Amount of LP tokens minted.
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /**
     * @notice Removes liquidity from a token pair.
     * @param tokenA Address of the first token.
     * @param tokenB Address of the second token.
     * @param liquidity Amount of LP tokens to burn.
     * @param amountAMin Minimum amount of the first token to receive.
     * @param amountBMin Minimum amount of the second token to receive.
     * @param to Recipient of the withdrawn tokens.
     * @param deadline Unix timestamp after which the operation must not execute.
     * @return amountA Amount of the first token withdrawn.
     * @return amountB Amount of the second token withdrawn.
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @notice Quotes the output amounts for a token swap path.
     * @param amountIn Input token amount.
     * @param path Token path from input token to output token.
     * @return amounts Expected amount at each step of the path.
     */
    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    /**
     * @notice Calculates the proportional amount of a second token for a liquidity deposit.
     * @param amountA Amount of the first token.
     * @param reserveA Reserve of the first token.
     * @param reserveB Reserve of the second token.
     * @return amountB Equivalent amount of the second token.
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
}
