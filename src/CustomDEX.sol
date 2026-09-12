// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CustomDEX {
    using SafeERC20 for IERC20;

    /// @notice Address of the Uniswap V2 router used for swaps and liquidity operations.
    address public immutable UNISWAP_V2_ROUTER_ADDRESS;
    address public immutable nftDavidCollection;

    event SwapTokens(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event AddLPTokens(address indexed tokenA_, address indexed tokenB_, uint256 lpTokensAmount);

    constructor(address uniswapV2RouterAddress_, address nftDavidCollection_) {
        require(uniswapV2RouterAddress_ != address(0) && nftDavidCollection_ != address(0), "Zero address");
        UNISWAP_V2_ROUTER_ADDRESS = uniswapV2RouterAddress_;
        nftDavidCollection = nftDavidCollection_;
    }

    function swapTokens(uint256 amountIn_, uint256 amountOutMin_, address[] memory path_, uint256 deadline_)
        external
        returns (uint256[] memory amountsOut)
    {
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountIn_);

        amountsOut = IV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokens(amountIn_, amountOutMin_, path_, msg.sender, deadline_);

        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountsOut[amountsOut.length - 1]);
    }

    function addLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 amountADesired_,
        uint256 amountBDesired_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external returns (uint256 lpTokensAmount) {
        IERC20(tokenA_).safeTransferFrom(msg.sender, address(this), amountADesired_);
        IERC20(tokenB_).safeTransferFrom(msg.sender, address(this), amountBDesired_);

        IERC20(tokenA_).approve(UNISWAP_V2_ROUTER_ADDRESS, amountADesired_);
        IERC20(tokenB_).approve(UNISWAP_V2_ROUTER_ADDRESS, amountBDesired_);
        (uint256 amountA, uint256 amountB, uint256 liquidity) = IV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .addLiquidity(
                tokenA_, tokenB_, amountADesired_, amountBDesired_, amountAMin_, amountBMin_, msg.sender, deadline_
            );

        // devolver el sobrante que no se usó
        if (amountA < amountADesired_) {
            IERC20(tokenA_).safeTransfer(msg.sender, amountADesired_ - amountA);
        }
        if (amountB < amountBDesired_) {
            IERC20(tokenB_).safeTransfer(msg.sender, amountBDesired_ - amountB);
        }

        lpTokensAmount = liquidity;
        emit AddLPTokens(tokenA_, tokenB_, lpTokensAmount);
    }

}
