//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

interface DefismStrategy{
    function longEth() external;
    function closeLongEth() external;
    function swapEthForDai() external;
    function swapDaiForEth() external;
    function closeShortETH() external;
    function shortETH() external;
    function withdraw(address token, uint amountDfsm) external;
    function deposit(address token, uint amount) external;
    function reserves() external returns (uint amountDai, uint amountETH);
}