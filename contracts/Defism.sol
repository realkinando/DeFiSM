//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DefismStrategy.sol";

contract Defism is ERC20, Ownable{

    enum States {
        LongEth,
        HoldEth,
        HoldDai,
        ShortEth
    }

    struct Proposal{
        uint deadlineBlock;
        States newState;
    }

    States public state;
    DefismStrategy strategy;
    uint16 minVoteBP;
    uint lastProposalExecuted;

    mapping(address => address) public delegates;
    mapping(address => uint) public addressVotes;
    mapping(uint => Proposal) public proposals;

    constructor(States initial, address strategyAddress, uint16 _minVoteBP) public{
        state = initial;
        strategy = DefismStrategy(strategyAddress);
        require(_minVoteBP < 10001);
        minVoteBP = _minVoteBP;
    }

    function setStrategy(address strategyAddress) external onlyOwner{
        strategy = DefismStrategy(strategyAddress);
        //emit event
    }

    function setMintVoteBP(uint16 _minVoteBP) external onlyOwner{
        require(_minVoteBP < 10001);
        minVoteBP = _minVoteBP;
        //emit event
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual{
        if (delegates[from]!=address(0)){
            votes[delegates[from]]-=amount;
        }
        else{
            votes[from]-=amount;
        }
        if (delegate[to]!=address(0)){
            votes[delegates[to]]+=amount;
        }
        else{
            votes[to]+=amount;
        }
    }

    function delegate(address delegateTo) external{
        if (delegates[msg.sender]!=address(0)){
            votes[delegates[msg.sender]] -= balanceOf(msg.sender);
        }
        else{
            votes[msg.sender] = 0;
        }
        if (delegateTo == address(0)){
            votes[msg.sender] = balanceOf(msg.sender);
        }
        else{
            votes[delegateTo] += balanceOf(msg.sender);
        }        
        delegates[msg.sender] = delegateTo;
        //emit event
    }

    function getReserves() external view returns (uint amountDai, uint amountETH){
        (bool success, bytes memory result) = strategy.delegateCall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        return abi.decode(result, (uint,uint));
    }

    function getTokenValue() external view returns (uint valueDai, uint valueETH){
        (bool success, bytes memory result) = strategy.delegateCall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        (uint amountDai, uint amountETH) = abi.decode(result, (uint,uint));
        return (amountDai/totalSupply(), amountETH/totalSupply());
        //might be a bug here
    }

    /** function deposit(address token, uint amount) external{
        require(state == States.HoldDai || state == States.HoldEth, "State doesn't allow deposits");
    }
        function withdraw(address token, uint amount) external{
        require(state == States.HoldDai || state == States.HoldEth, "State doesn't allow withdrawals");
    }
    **/

    //function createProposal()

    //function voteProposal()

    // function executeProposal()

    function stateTransition(States newState) internal{

        bool success;
        bytes memory result;

        if(newState == States.LongEth){
            require(state == States.LongEth || state == States.HoldEth,"Invalid state transistion");
            (success, result) = strategy.delegateCall(abi.encodeWithSignature("longEth()"));
        }

        else if(newState == States.HoldEth){
            if(state == States.LongEth){
                (success, result) = strategy.delegateCall(abi.encodeWithSignature("closeLongEth()"));
            }
            else if(state == States.HoldDai){
                (success, result) = strategy.delegateCall(abi.encodeWithSignature("swapDaiForEth()"));
            }
            else{
                revert("Invalid state transistion");
            }
        }

        else if(newState == States.HoldDai){
            if(state == States.HoldEth){
                (success, result) = strategy.delegateCall(abi.encodeWithSignature("swapEthForDai()"));
            }
            else if(state == States.ShortEth){
                (success, result) = strategy.delegateCall(abi.encodeWithSignature("closeShortEth()"));
            }
            else{
                revert("Invalid state transistion");
            }
        }

        else{
            require(state == States.ShortEth || state == States.HoldDai,"Invalid state transistion");
            (success, result) = strategy.delegateCall(abi.encodeWithSignature("shortEth()"));
        }

        require(success);
    }


     
}