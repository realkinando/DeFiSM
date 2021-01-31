//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "../interfaces/IOneSplit.sol";
import "../utils/UniversalERC20.sol";
import { IFlashLoanReceiver, ILendingPoolAddressesProvider, ILendingPool } from "../interfaces/IFlashLoan.sol";


contract ETHDAI is IFlashLoanReceiver{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    enum Status {
        HOLD_ETH,
        HOLD_DAI,
        LONG_ETH,
        SHORT_ETH
    }

    Status public status;

    IOneSplit split = IOneSplit(0x50FDA034C0Ce7a8f7EFDAebDA7Aa7cA21CC1267e); // 1split.eth
    ILendingPoolAddressesProvider public override ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    ILendingPool public override LENDING_POOL = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    address aave;
    address oneInch;
    address uni;

    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant AETH_ADDRESS = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04; // V1
    address public constant ADAI_ADDRESS = 0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d; // V1
    

    // constructor(AaveLogic _aave, UniswapLogic _uni){
    constructor(address _aave, address _oneInch, address _uni){
        aave = _aave;
        oneInch = _oneInch;
        uni = _uni;
    }

    function deposit(address token, uint amount) internal{
        (bool success, ) = 
            aave.delegatecall(abi.encodeWithSignature("deposit(address,uint256)",token, amount));
        require(success);
    }

    function withdraw(address token, uint amount) internal{
        (bool success, ) = 
            aave.delegatecall(abi.encodeWithSignature("withdraw(address,uint256)",token, amount));
        require(success);
    }

    function borrow(address token, uint amount) internal{
        (bool success, ) = 
            aave.delegatecall(abi.encodeWithSignature("borrow(address,uint256)",token, amount));
        require(success);
    }

    function payback(address token, uint amount) internal{
        (bool success, ) = 
            aave.delegatecall(abi.encodeWithSignature("payback(address,uint256)",token, amount));
        require(success);
    }

    function swap(address from, address to, uint amt) internal{
        (bool success, ) = 
            uni.delegatecall(abi.encodeWithSignature("swap(address,address,uint256)",from, to, amt));
        require(success);
    }

    function getBalance(address token) internal view returns(uint){
       return IERC20(token).universalBalanceOf(address(this));        
    }

    function getDebt(address token) internal returns(uint debtAmt){
       (bool success, bytes memory result) = 
            aave.delegatecall(abi.encodeWithSignature("getDebt(address)",token));
        require(success);

        debtAmt = abi.decode(result, (uint));
    }

    function getWithdrawAmt(address token) internal returns(uint amount){
        (bool success, bytes memory result) = 
            aave.delegatecall(abi.encodeWithSignature("getWithdrawBalance(address)",token));
        require(success);

        amount = abi.decode(result, (uint));
    }    

    function openETHLong() internal{

        uint ethBalance = getBalance(ETH_ADDRESS);
        console.log("ETH amount", ethBalance);

        // Deposit ETH to Aave
        deposit(ETH_ADDRESS, ethBalance);

        // Borrow DAI from Aave
        borrow(DAI_ADDRESS, 500 ether);

        uint daiBalance = getBalance(DAI_ADDRESS);
        console.log("DAI balance", daiBalance);

        // Swap DAI for ETH in Uniswap
        swap(DAI_ADDRESS, ETH_ADDRESS, 500 ether);

        ethBalance = getBalance(ETH_ADDRESS);
        console.log("ETH amount", ethBalance);

        // Deposit swapped ETH to Aave
        deposit(ETH_ADDRESS, ethBalance);

        // // Swap DAI for ETH in 1Inch
        // (success, ) = 
        //     oneInch.delegatecall(
        //         abi.encodeWithSignature(
        //             "swap(address,address,uint256,uint256,uint256[])",
        //             DAI_ADDRESS,
        //             ETH_ADDRESS, 
        //             uint(-1),
        //             0,
        //             // distribution
        //             [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0]
        //         ));
        // require(success);
        
    }

    function openETHShort() internal{

        uint startBalance = getBalance(DAI_ADDRESS);
        console.log("Start DAI amount", startBalance);

        // Deposit DAI to Aave
        deposit(DAI_ADDRESS, startBalance);

        // Borrow ETH from Aave (how much??)
        borrow(ETH_ADDRESS, 1 ether);

        uint ethBalance = getBalance(ETH_ADDRESS);
        console.log("ETH balance", ethBalance);

        // Swap ETH for DAI in Uniswap
        swap(ETH_ADDRESS, DAI_ADDRESS, uint(-1));

        uint daiBalance = getBalance(DAI_ADDRESS);
        console.log("DAI amount", daiBalance);

        // // Swap DAI for ETH in 1Inch
        // (success, ) = 
        //     oneInch.delegatecall(
        //         abi.encodeWithSignature(
        //             "swap(address,address,uint256,uint256,uint256[])",
        //             DAI_ADDRESS,
        //             ETH_ADDRESS, 
        //             uint(-1),
        //             0,
        //             // distribution
        //             [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0]
        //         ));
        // require(success);

        // Deposit swapped DAI to Aave
        deposit(DAI_ADDRESS, daiBalance);

        
    }

    // DAI debt, end up with all balance in DAI
    function closeETHLong() internal{
        uint debtAmt = getDebt(DAI_ADDRESS);
        console.log("Debt Amount", debtAmt);

        repayDebt(DAI_ADDRESS, debtAmt);        
    }

    // ETH debt, end up with all balance in ETH
    function closeETHShort() internal{
        uint debtAmt = getDebt(ETH_ADDRESS);
        console.log("Debt Amount", debtAmt);

        repayDebt(ETH_ADDRESS, debtAmt);        
    }

    function longETH() public{
        uint ethBalance = getBalance(ETH_ADDRESS);
        console.log("Starting ETH balance", ethBalance);

        // If holding DAI, first swap all DAI to ETH
        if(status == Status.HOLD_DAI){
            swap(DAI_ADDRESS, ETH_ADDRESS, uint(-1));
        }

        // If shorting ETH, first close eth short position
        if(status == Status.SHORT_ETH){
            closeETHShort();
        }

        // If already longing ETH, revert
        if(status == Status.LONG_ETH){
            revert();
        }

        // If holding ETH, nothing to do.

        openETHLong();

        status = Status.LONG_ETH;

        uint aEthBalance = getBalance(AETH_ADDRESS);
        console.log("Final aETH balance", aEthBalance);
    }

    function shortETH() public{
        // If holding ETH, first swap all ETH to DAI
        if(status == Status.HOLD_ETH){
            swap(ETH_ADDRESS, DAI_ADDRESS, uint(-1));
        }

        // If shorting ETH, first close eth short position
        if(status == Status.LONG_ETH){
            closeETHLong();
        }

        // If already shorting ETH, revert
        if(status == Status.SHORT_ETH){
            revert();
        }

        // If holding DAI, nothing to do.

        openETHShort();

        status = Status.SHORT_ETH;

        uint aDaiBalance = getBalance(ADAI_ADDRESS);
        console.log("Final aDAI balance", aDaiBalance);
    }

    function holdDAI() public{

        uint daiBalance = getBalance(DAI_ADDRESS);
        console.log("Starting DAI balance", daiBalance);

        // If holding ETH, only swap all ETH to DAI
        if(status == Status.HOLD_ETH){
            swap(ETH_ADDRESS, DAI_ADDRESS, uint(-1));
        }

        // If shorting ETH, only close eth long position
        if(status == Status.LONG_ETH){
            closeETHLong();
        }

        // If shorting ETH, close short and then
        if(status == Status.SHORT_ETH){
            closeETHShort();

            // Temporal, until figure out data
            swap(ETH_ADDRESS, DAI_ADDRESS, uint(-1));
        }

        daiBalance = getBalance(DAI_ADDRESS);
        console.log("FinalDAI balance", daiBalance);

        // Update status
        status = Status.HOLD_DAI;
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        console.log("Flashloan Asset", assets[0]);
        console.log("Flashloan Amt", amounts[0]);

        address collateralToken = assets[0] == DAI_ADDRESS ? ETH_ADDRESS :DAI_ADDRESS;

        // Payback all debt to Aave
        payback(assets[0], uint(-1));

        // At this point user has collateral only
        uint withdrawAmt = getWithdrawAmt(collateralToken);
        console.log("Amount Collateral to withdraw", withdrawAmt);

        // Withdraw all Collateral from Aave (TODO: determine how much to withdraw)
        withdraw(collateralToken, withdrawAmt);

        // Swap Collateral for debt token in Uniswap to payback flashloan
        swap(collateralToken, assets[0], withdrawAmt);

        // At the end of your logic above, this contract owes
        // the flashloaned amounts + premiums.
        // Therefore ensure your contract has enough to repay
        // these amounts.

        // Approve the LendingPool contract allowance to *pull* the owed amount
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }


    /**
        1. Takes flashloan on debt token, 
        2. Repays Aave's debt
        3. Withdraws all collateral
        4. Swaps all collateral for debt token
        5. Repays flashloan
        6. Ends up with same debt token
     */
    
    
    function repayDebt(address asset, uint amount) public {
        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    receive() external payable {} 

}