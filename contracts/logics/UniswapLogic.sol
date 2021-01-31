//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Exchange.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IWETH.sol";
import "../utils/UniversalERC20.sol";

contract UniswapLogic {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;
    using UniswapV2ExchangeLib for IUniswapV2Exchange;

    IUniswapV2Factory internal constant factory = IUniswapV2Factory(
        0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f
    );

    IUniswapV2Router router = IUniswapV2Router(
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );

    IWETH internal constant weth = IWETH(
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    );

    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) external payable {
        uint256 realAmt = amount == uint256(-1)
            ? fromToken.universalBalanceOf(address(this))
            : amount;

        uint256 returnAmount = 0;

        if (fromToken.isETH()) {
            weth.deposit{value:realAmt}();
        }

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 toTokenReal = destToken.isETH() ? weth : destToken;

        IUniswapV2Exchange exchange = factory.getPair(
            fromTokenReal,
            toTokenReal
        );
        returnAmount = exchange.getReturn(fromTokenReal, toTokenReal, realAmt);

        fromTokenReal.universalTransfer(address(exchange), realAmt);

        if (uint256(address(fromTokenReal)) < uint256(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    receive() external payable {}
}