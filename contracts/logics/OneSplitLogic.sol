//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../interfaces/IOneSplit.sol";

contract OneSplitLogic {
    IOneSplit split = IOneSplit(0xC586BeF4a0992C495Cf22e1aeEE4E446CECDee0E); // 1split.eth
    // IOneSplit split = IOneSplit(0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e); // 1split.eth

    function getAddressETH() public pure returns (address eth) {
        eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function getBalance(address token) public view returns (uint256) {
        if (token == getAddressETH()) return address(this).balance;
        return IERC20(token).balanceOf(address(this));
    }

    function swap(
        IERC20 src,
        IERC20 dest,
        uint256 amtSrc,
        uint256 minReturn,
        uint256[] memory dist
    ) public payable {
        uint256 realSrcAmt = amtSrc == uint(-1) ? getBalance(address(src)) : amtSrc;

        if (address(src) != getAddressETH()) {
            src.approve(address(split), realSrcAmt);
            split.swap(src, dest, realSrcAmt, minReturn, dist, 0);
        } else {
            split.swap{value:realSrcAmt}(
                src,
                dest,
                realSrcAmt,
                minReturn,
                dist,
                0
            );
        }
    }

    receive() external payable {}
}