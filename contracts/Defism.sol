//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDefismStrategy.sol";

contract Defism is ERC20, Ownable{

    enum States {
        LongEth,
        HoldEth,
        HoldDai,
        ShortEth
    }

    struct Proposal{
        uint deadline;
        States newState;
    }

    States public state;
    IDefismStrategy strategy;
    uint16 public minVoteBP;
    uint public lastProposalExecuted;
    uint public totalProposals;
    uint public voteTimeout;

    mapping(address => address) public delegates;
    mapping(address => uint) public votes;
    mapping(uint => Proposal) public proposals;
    mapping(uint => uint) public proposalVotes;

    mapping(address => uint) public addressProposalLastVoted;
    mapping(address => uint) public addressTimeLastVoted;

    address WETH;
    address DAI;

    constructor(States initial, 
                address strategyAddress, address _weth, address _dai, 
                uint16 _minVoteBP, uint _voteTimeout) 
                ERC20("DefiSM","DSM"){
                    state = initial;
                    strategy = IDefismStrategy(strategyAddress);
                    voteTimeout = _voteTimeout;
                    require(_minVoteBP < 10001);
                    minVoteBP = _minVoteBP;
                    WETH = _weth;
                    DAI = _dai;
    }

    function setStrategy(address strategyAddress) external onlyOwner{
        strategy = IDefismStrategy(strategyAddress);
        //emit event
    }

    function setMintVoteBP(uint16 _minVoteBP) external onlyOwner{
        require(_minVoteBP < 10001);
        minVoteBP = _minVoteBP;
        //emit event
    }

    //moves votes when transfers occur, gas inefficient currently
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override{
        if (delegates[from]!=address(0)){
            votes[delegates[from]]-=amount;
            proposalVotes[addressProposalLastVoted[delegates[from]]] -= amount;
        }
        else{
            votes[from]-=amount;
            proposalVotes[addressProposalLastVoted[from]] -= amount;
        }
        if (delegates[to]!=address(0)){
            votes[delegates[to]]+=amount;
            proposalVotes[addressProposalLastVoted[delegates[from]]] += amount;
        }
        else{
            votes[to]+=amount;
            proposalVotes[addressProposalLastVoted[delegates[from]]] += amount;
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

    function getReserves() public returns (uint amountDai, uint amountETH){
        (bool success, bytes memory result) = address(strategy).delegatecall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        return abi.decode(result, (uint,uint));
    }

    //returns value * 1000
    function getTokenValue() public returns (uint valueDai, uint valueETH){
        (bool success, bytes memory result) = address(strategy).delegatecall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        (uint amountDai, uint amountETH) = abi.decode(result, (uint,uint));
        return (amountDai*1000/totalSupply(), amountETH*1000/totalSupply());
    }

    function deposit(address token, uint amount) external{
        require((state == States.HoldDai && token == DAI) || (state == States.HoldEth && token == WETH), "Current state doesn't deposits in chosen token");
        uint preTradeTotalSupply = totalSupply();
        (bool success, bytes memory result) = address(strategy).delegatecall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        (uint reserveDai, uint reserveETH) = abi.decode(result, (uint,uint));
        (bool success1, bytes memory result1) = address(strategy).delegatecall(abi.encodeWithSignature("deposit(address,uint)",token,amount));
        require(success1, "Deposit() delegate call failed");
        uint give;
        if(token == DAI){
            give = preTradeTotalSupply*amount/reserveDai;
        }
        else{
            give = preTradeTotalSupply*amount/reserveETH;
        }
        _mint(msg.sender,give);
    }

    function withdraw(address token, uint amount) external{
        require((state == States.HoldDai && token == DAI) || (state == States.HoldEth && token == WETH), "Current state doesn't withdrawals in chosen token");
        uint preTradeTotalSupply = totalSupply();
        (bool success, bytes memory result) = address(strategy).delegatecall(abi.encodeWithSignature("reserves()"));
        require(success, "Reserves() delegate call failed");
        (uint reserveDai, uint reserveETH) = abi.decode(result, (uint,uint));
        (bool success1, bytes memory result1) = address(strategy).delegatecall(abi.encodeWithSignature("withdraw(address,uint)",token,amount));
        require(success1, "Deposit() delegate call failed");
        uint take;
        if(token == DAI){
            take = preTradeTotalSupply*amount/reserveDai;
        }
        else{
            take = preTradeTotalSupply*amount/reserveETH;
        }
        _burn(msg.sender,take);
    }


    function createProposal(uint deadline, States newState) external {
        require(deadline < block.timestamp,"Invalid deadline");
        proposals[totalProposals] = Proposal(deadline,newState);
        totalProposals++;
    }

    function proposalLive(uint proposalId) internal view returns(bool live){
        live = false;
        if(lastProposalExecuted < proposalId 
            &&  
            proposalId < totalProposals 
            &&
            proposals[proposalId].deadline < block.timestamp){
                live = true;
            }
    }

    function voteProposal(uint proposalId) external{
        require(lastProposalExecuted < proposalId &&  proposalId < totalProposals, "Invalid proposalId");
        require(proposals[proposalId].deadline < block.timestamp, "Proposal Expired");
        require(addressTimeLastVoted[msg.sender] + voteTimeout < block.timestamp, "Voted Too Recently");
        if (proposalLive(addressProposalLastVoted[msg.sender])){
            proposalVotes[addressProposalLastVoted[msg.sender]] -= votes[msg.sender];
        }
        proposalVotes[proposalId] += votes[msg.sender];
        addressProposalLastVoted[msg.sender] = proposalId;
        addressTimeLastVoted[msg.sender] = block.timestamp;
    }

    function executeProposal(uint proposalId) external{
        //verify proposal reached limit
        require (proposalVotes[proposalId] > (10000*totalSupply()/minVoteBP), "Not enough votes");
        //verify proposal is current
        require (proposalId>lastProposalExecuted,"Not current");
        //do transistion
        stateTransition(proposals[proposalId].newState);
        //update
        lastProposalExecuted = proposalId;
        //emit event
    }

    function stateTransition(States newState) internal{

        bool success;
        bytes memory result;

        if(newState == States.LongEth){
            require(state == States.LongEth || state == States.HoldEth,"Invalid state transistion");
            (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("longEth()"));
        }

        else if(newState == States.HoldEth){
            if(state == States.LongEth){
                (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("closeLongEth()"));
            }
            else if(state == States.HoldDai){
                (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("swapDaiForEth()"));
            }
            else{
                revert("Invalid state transistion");
            }
        }

        else if(newState == States.HoldDai){
            if(state == States.HoldEth){
                (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("swapEthForDai()"));
            }
            else if(state == States.ShortEth){
                (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("closeShortEth()"));
            }
            else{
                revert("Invalid state transistion");
            }
        }

        else{
            require(state == States.ShortEth || state == States.HoldDai,"Invalid state transistion");
            (success, result) = address(strategy).delegatecall(abi.encodeWithSignature("shortEth()"));
        }
        require(success);
    }


     
}