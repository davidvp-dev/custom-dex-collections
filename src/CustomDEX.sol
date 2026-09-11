// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CustomDEX {
    using SafeERC20 for IERC20;

    address public V2Router02Address;
    event SwapTokens(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address V2Router02Address_) {
        V2Router02Address = V2Router02Address_;
    }

    function swapTokens(uint256 amountIn_, uint256 amountOut_, address[] memory path_, uint256 deadline_) external {
        // 1. cogemos los USDT del msg sender
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        // 2. hay que permitir que Uniswap coja los tokens de este SC
        IERC20(path_[0]).approve(V2Router02Address, amountIn_);
        // 3. ejecutamos el swap con Uniswap V2 Router
        uint[] memory amountsOut = IV2Router02(V2Router02Address).swapExactTokensForTokens(amountIn_, amountOut_, path_, msg.sender, deadline_);
        
        emit SwapTokens(path_[0], path_[path_.length -1], amountIn_, amountOut_);
    }


}