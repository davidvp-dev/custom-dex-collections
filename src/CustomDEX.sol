// SPDX-License-Identifier: MIT

pragma solidity 0.8.34;

import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "./interfaces/IUniswapV2Factory.sol";
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { Ownable2Step, Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable2Step.sol";

/**
 * @title Custom DEX
 * @notice Provides token swaps and liquidity deposits through a Uniswap V2 router.
 */
contract CustomDEX is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 public feeBps = 100; //1% fees
    uint256 public constant MAX_FEE_BPS = 500; //5% max fees
    address public feeRecipient;

    address public immutable UNISWAP_V2_ROUTER_ADDRESS;
    address public immutable UNISWAP_V2_FACTORY_ADDRESS;

    event SwapTokens(
        address indexed tokenIn_, address indexed tokenOut_, uint256 amountIn_, uint256 amountOut_, uint256 protocolFee_
    );
    event AddLPTokens(address indexed tokenA_, address indexed tokenB_, uint256 lpTokensAmount_);
    event RemoveLPTokens(
        address indexed tokenA_, address indexed tokenB_, uint256 liquidity_, uint256 amountA_, uint256 amountB_
    );
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);

    /**
     * @notice Initializes the DEX with a Uniswap V2 router, factory, and protocol fee recipient.
     * @param uniswapV2RouterAddress_ Address of the Uniswap V2 router to use.
     * @param uniswapV2FactoryAddress_ Address of the Uniswap V2 factory.
     * @param feeRecipient_ Address that receives protocol fees.
     */
    constructor(address uniswapV2RouterAddress_, address uniswapV2FactoryAddress_, address feeRecipient_)
        Ownable(msg.sender)
    {
        require(
            uniswapV2RouterAddress_ != address(0) && uniswapV2FactoryAddress_ != address(0)
                && feeRecipient_ != address(0),
            "Zero address"
        );
        UNISWAP_V2_FACTORY_ADDRESS = uniswapV2FactoryAddress_;
        UNISWAP_V2_ROUTER_ADDRESS = uniswapV2RouterAddress_;
        feeRecipient = feeRecipient_;
    }

    /**
     * @notice Receives native ETH sent directly to the contract.
     */
    receive() external payable { }

    /**
     * @notice Swaps exact input tokens for output tokens through Uniswap V2, applying protocol fee.
     * @dev The caller must approve this contract to spend `amountIn_` of the first token in `path_`.
     * @param amountIn_ Exact amount of input tokens to swap.
     * @param amountOutMin_ Minimum acceptable amount of output tokens.
     * @param path_ Token path from input token to output token.
     * @param deadline_ Unix timestamp after which the swap must not execute.
     * @return amounts Same as Uniswap's amountsOut, except the last element is net of protocol fee.
     */
    function swapTokens(uint256 amountIn_, uint256 amountOutMin_, address[] memory path_, uint256 deadline_)
        external
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(amountIn_ > 0, "Invalid amount");

        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountIn_);

        amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .swapExactTokensForTokens(amountIn_, amountOutMin_, path_, address(this), deadline_);

        address tokenOut_ = path_[path_.length - 1];
        uint256 amountOut_ = amounts[amounts.length - 1];

        (uint256 amountAfterFee_, uint256 protocolFee_) = _applyFeeAndForwardTokens(tokenOut_, msg.sender, amountOut_);

        amounts[amounts.length - 1] = amountAfterFee_;

        emit SwapTokens(path_[0], tokenOut_, amountIn_, amountAfterFee_, protocolFee_);
    }

    /**
     * @notice Swaps the supplied native ETH for ERC20 tokens through Uniswap V2, applying the protocol fee.
     * @param amountOutMin_ Minimum acceptable amount of output tokens before the protocol fee.
     * @param path_ Token path from the wrapped native token to the output token.
     * @param deadline_ Unix timestamp after which the swap must not execute.
     * @return amounts Same as Uniswap's amountsOut, except the last element is net of protocol fee.
     */
    function swapEthForERC20Tokens(uint256 amountOutMin_, address[] calldata path_, uint256 deadline_)
        external
        payable
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(msg.value > 0, "Please provide a valid ETH amount");
        amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS).swapExactETHForTokens{ value: msg.value }(
            amountOutMin_, path_, address(this), deadline_
        );

        address tokenOut_ = path_[path_.length - 1];
        uint256 amountOut_ = amounts[amounts.length - 1];

        (uint256 amountAfterFee_, uint256 protocolFee_) = _applyFeeAndForwardTokens(tokenOut_, msg.sender, amountOut_);

        amounts[amounts.length - 1] = amountAfterFee_;

        emit SwapTokens(path_[0], tokenOut_, msg.value, amountAfterFee_, protocolFee_);
    }

    /**
     * @notice Swaps exact input ERC20 tokens for native ETH through Uniswap V2, applying the protocol fee.
     * @dev The caller must approve this contract to spend `amountIn_` of the first token in `path_`.
     * @param amountIn_ Exact amount of input tokens to swap.
     * @param amountOutMin_ Minimum acceptable amount of native ETH before the protocol fee.
     * @param path_ Token path from the input token to the wrapped native token.
     * @param deadline_ Unix timestamp after which the swap must not execute.
     * @return amounts Same as Uniswap's amountsOut, except the last element is net of protocol fee.
     */
    function swapERC20TokensForEth(
        uint256 amountIn_,
        uint256 amountOutMin_,
        address[] calldata path_,
        uint256 deadline_
    ) external nonReentrant returns (uint256[] memory amounts) {
        require(amountIn_ > 0, "Please provide a valid amount");
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountIn_);

        amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .swapExactTokensForETH(amountIn_, amountOutMin_, path_, address(this), deadline_);

        uint256 ethAmount_ = amounts[amounts.length - 1];

        (uint256 amountAfterFee_, uint256 protocolFee_) = _applyFeeAndForwardEth(msg.sender, ethAmount_);

        amounts[amounts.length - 1] = amountAfterFee_;

        emit SwapTokens(path_[0], address(0), amountIn_, amountAfterFee_, protocolFee_); // address(0) is native ETH
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

        IERC20(tokenA_).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountADesired_);
        IERC20(tokenB_).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, amountBDesired_);
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

    /**
     * @notice Removes liquidity from a Uniswap V2 pair and sends the underlying tokens to the caller.
     * @dev The caller must approve this contract to spend `liquidity_` LP tokens for the pair. The router enforces the minimum return amounts.
     * @param tokenA_ Address of the first token in the liquidity pair.
     * @param tokenB_ Address of the second token in the liquidity pair.
     * @param liquidity_ Amount of LP tokens to burn from the caller.
     * @param amountAMin_ Minimum amount of the first token to receive.
     * @param amountBMin_ Minimum amount of the second token to receive.
     * @param deadline_ Unix timestamp after which the liquidity removal must not execute.
     * @return amountA_ Amount of the first token returned to the caller.
     * @return amountB_ Amount of the second token returned to the caller.
     */
    function removeLiquidity(
        address tokenA_,
        address tokenB_,
        uint256 liquidity_,
        uint256 amountAMin_,
        uint256 amountBMin_,
        uint256 deadline_
    ) external returns (uint256 amountA_, uint256 amountB_) {
        address pair_ = IUniswapV2Factory(UNISWAP_V2_FACTORY_ADDRESS).getPair(tokenA_, tokenB_);
        require(pair_ != address(0), "Pair not found");

        IERC20(pair_).safeTransferFrom(msg.sender, address(this), liquidity_);
        IERC20(pair_).forceApprove(UNISWAP_V2_ROUTER_ADDRESS, liquidity_);

        (amountA_, amountB_) = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDRESS)
            .removeLiquidity(tokenA_, tokenB_, liquidity_, amountAMin_, amountBMin_, msg.sender, deadline_);

        emit RemoveLPTokens(tokenA_, tokenB_, liquidity_, amountA_, amountB_);
    }

    /**
     * @notice Updates the address that receives the protocol fee.
     * @dev Only the contract owner can change the fee recipient.
     * @param newRecipient_ Address that will receive future protocol fees.
     */
    function setFeeRecipient(address newRecipient_) external onlyOwner {
        require(newRecipient_ != address(0), "The recipient must be a valid address");
        emit FeeRecipientUpdated(feeRecipient, newRecipient_);
        feeRecipient = newRecipient_;
    }

    /**
     * @notice Updates the protocol fee percentage used in swaps.
     * @dev Only the contract owner can change the fee rate; the value cannot exceed `MAX_FEE_BPS`.
     * @param newFeeBps_ New fee rate in basis points, where 100 = 1%.
     */
    function setFeeBps(uint256 newFeeBps_) external onlyOwner {
        require(newFeeBps_ <= MAX_FEE_BPS, "Fee exceeds max");
        emit FeeBpsUpdated(feeBps, newFeeBps_);
        feeBps = newFeeBps_;
    }

    /**
     * @notice Deducts the protocol fee from an ERC20 amount and forwards the fee and remainder.
     * @param token_ Address of the output token.
     * @param user_ Address receiving the amount after fees.
     * @param amountIn_ Gross amount of output tokens before the protocol fee.
     * @return amountAfterFee_ Amount of tokens forwarded to the user.
     * @return protocolFee_ Amount of tokens forwarded to the fee recipient.
     */
    function _applyFeeAndForwardTokens(address token_, address user_, uint256 amountIn_)
        internal
        returns (uint256 amountAfterFee_, uint256 protocolFee_)
    {
        protocolFee_ = (amountIn_ * feeBps) / 10_000;
        amountAfterFee_ = amountIn_ - protocolFee_;

        if (protocolFee_ > 0) {
            IERC20(token_).safeTransfer(feeRecipient, protocolFee_);
        }
        IERC20(token_).safeTransfer(user_, amountAfterFee_);
    }

    /**
     * @notice Deducts the protocol fee from a native ETH amount and forwards the fee and remainder.
     * @param user_ Address receiving the amount after fees.
     * @param amountIn_ Gross amount of native ETH before the protocol fee.
     * @return amountAfterFee_ Amount of ETH forwarded to the user.
     * @return protocolFee_ Amount of ETH forwarded to the fee recipient.
     */
    function _applyFeeAndForwardEth(address user_, uint256 amountIn_)
        internal
        returns (uint256 amountAfterFee_, uint256 protocolFee_)
    {
        protocolFee_ = (amountIn_ * feeBps) / 10_000;
        amountAfterFee_ = amountIn_ - protocolFee_;

        if (protocolFee_ > 0) {
            (bool feeSuccess,) = feeRecipient.call{ value: protocolFee_ }("");
            require(feeSuccess, "ETH fee transfer failed.");
        }
        (bool userSuccess,) = user_.call{ value: amountAfterFee_ }("");
        require(userSuccess, "ETH transfer to user failed.");
    }
}
