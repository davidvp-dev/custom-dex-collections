// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import "./interfaces/IUniswapV2Router02.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Custom DEX
 * @notice Provides token swaps and liquidity deposits through a Uniswap V2 router.
 */
contract CustomDEX {
    using SafeERC20 for IERC20;

    /** @notice Address of the Uniswap V2 router used for swaps and liquidity operations. */
    address public immutable UNISWAP_V2_ROUTER_ADDRESS;

    /** @notice Address of the NFT collection associated with this deployment. */
    address public immutable nftDavidCollection;

    /** @notice Emitted when tokens are swapped through the configured router. */
    event SwapTokens(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /** @notice Emitted when liquidity is added and LP tokens are minted for the caller. */
    event AddLPTokens(address indexed tokenA_, address indexed tokenB_, uint256 lpTokensAmount);

    /**
     * @notice Initializes the DEX with a Uniswap V2 router and an NFT collection address.
     * @param uniswapV2RouterAddress_ Address of the Uniswap V2 router to use.
     * @param nftDavidCollection_ Address of the associated NFT collection.
     */
    constructor(address uniswapV2RouterAddress_, address nftDavidCollection_) {
        require(uniswapV2RouterAddress_ != address(0) && nftDavidCollection_ != address(0), "Zero address");
        UNISWAP_V2_ROUTER_ADDRESS = uniswapV2RouterAddress_;
        nftDavidCollection = nftDavidCollection_;
    }

    /**
     * @notice Swaps an exact amount of input tokens for output tokens through Uniswap V2.
     * @dev The caller must approve this contract to spend `amountIn_` of the first token in `path_`.
     * @param amountIn_ Exact amount of input tokens to swap.
     * @param amountOutMin_ Minimum acceptable amount of output tokens.
     * @param path_ Token path from input token to output token.
     * @param deadline_ Unix timestamp after which the swap must not execute.
     * @return amountsOut Amounts received at each step of the swap path.
     */
    function swapTokens(uint256 amountIn_, uint256 amountOutMin_, address[] memory path_, uint256 deadline_)
        external
        returns (uint256[] memory amountsOut)
    {
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountIn_);

        amountsOut = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokens(amountIn_, amountOutMin_, path_, msg.sender, deadline_);

        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountsOut[amountsOut.length - 1]);
    }

    /**
     * @notice Adds token liquidity through Uniswap V2 and sends LP tokens to the caller.
     * @dev The caller must approve this contract to spend both desired token amounts. Any unused input tokens are returned to the caller.
     * @param tokenA_ Address of the first token in the liquidity pair.
     * @param tokenB_ Address of the second token in the liquidity pair.
     * @param amountADesired_ Desired amount of the first token to deposit.
     * @param amountBDesired_ Desired amount of the second token to deposit.
     * @param amountAMin_ Minimum amount of the first token accepted by the router.
     * @param amountBMin_ Minimum amount of the second token accepted by the router.
     * @param deadline_ Unix timestamp after which the liquidity addition must not execute.
     * @return lpTokensAmount Amount of LP tokens minted for the caller.
     */
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
        (uint256 amountA, uint256 amountB, uint256 liquidity) = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .addLiquidity(
                tokenA_, tokenB_, amountADesired_, amountBDesired_, amountAMin_, amountBMin_, msg.sender, deadline_
            );

        // If any tokens that we sent to the pool were not included in the LP, those are sent back to the user
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
