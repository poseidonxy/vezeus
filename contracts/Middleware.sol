// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract VotingContract {
    function createBallot(string memory name,string[] memory _choices,uint256 offset) public virtual;
    function vote(address account, uint256 ballotId, uint256 choiceId, uint256 amount) external virtual;
}

abstract contract MembershipContract {
    function isMember(address member) virtual external view returns (bool);
    function subscribe(address member) external virtual;
    function unSubscribe(address member) external virtual;
}

abstract contract HandlerContract {
    function getTransaction(uint256 _txId) virtual external view 
        returns(address _owner, uint256 _amount, uint256 _timestamp);
    function getLockedFund(address account) virtual external view 
        returns(address _owner, uint256 _amount, uint256 _timestamp);
    function queue(address _owner, uint256 _amount) external virtual returns (uint256);
    function cancel(uint256 _txId, address _owner) external virtual returns(uint256);
    function execute(uint256 _txId) external virtual returns(address, uint256);
    function withdraw(address account) external virtual returns(uint256, uint256);
}

abstract contract VeZeusContract {
    function stake(address account, uint256 amount) external virtual;
    function withdrawVeZeus(address account) external virtual returns(uint256);
}

contract Middleware {
    using SafeMath for uint;

    address public currentBallotCreator;
    address public admin;
    address public collector = 0x67dD4EA99CE6453f28DA3b08d0257063189121e6;
    address public vzeusCollector = 0x67dD4EA99CE6453f28DA3b08d0257063189121e6;

    uint256 public waitingTime = 60; //1 minute pending time
    uint256 public maxDeposit = 2;
    uint256 public minDeposit = 1;
    uint256 public lastRun;
    mapping(address => uint256) public lastInit;
    uint256[4] public lockupPayoutPercentages = [60,70, 80];
    mapping(address => uint256) public timeBeforeStaking;

    address public votingContractAddress;
    address public membershipContractAddress;
    address public handlerContractAddress;
    address public veZeusContractAddress;
    VotingContract votingContract;
    MembershipContract membershipContract;
    HandlerContract handlerContract;
    VeZeusContract veZeusContract;
    ERC20 USDC = ERC20(0x5425890298aed601595a70AB815c96711a31Bc65);
    ERC20 VEZEUS = ERC20(0x13F88dfA55fb50F9BE742869EC5f35D16d6B7a8f);
    ERC20 Zeus = ERC20(0x68259522E52d8Cc1dF7bCF0Aa08aD9aca32983f5);

    constructor(address _votingContractAddress, address _membershipContractAddress, 
        address _handlerContractAddress, address _veContractAddress) {
        admin = msg.sender;
        votingContractAddress = _votingContractAddress;
        membershipContractAddress = _membershipContractAddress;
        handlerContractAddress = _handlerContractAddress;
        veZeusContractAddress = _veContractAddress;
        votingContract = VotingContract(_votingContractAddress);
        membershipContract = MembershipContract(_membershipContractAddress);
        handlerContract = HandlerContract(_handlerContractAddress);
        veZeusContract = VeZeusContract(_veContractAddress);
        
    }

    function updateTokens(address _usdc, address _vezeus, address _zeus) external onlyAdmin{
        USDC = ERC20(_usdc);
        VEZEUS = ERC20(_vezeus);
        Zeus = ERC20(_zeus);
    }

    function updateVotingContract(address _votingContractAddress
    ) external onlyAdmin {
        votingContractAddress = _votingContractAddress;
        votingContract = VotingContract(_votingContractAddress);
    }

    function updateMembershipContract(address _membershipContractAddress
    ) external onlyAdmin {
        membershipContractAddress = _membershipContractAddress;
        membershipContract = MembershipContract(_membershipContractAddress);
    }

    function updateHandlerContract(address _handlerContractAddress
    ) external onlyAdmin {
        handlerContractAddress = _handlerContractAddress;
        handlerContract = HandlerContract(_handlerContractAddress);
    }

    function updateVeZeusContract(address _veContractAddress
    ) external onlyAdmin {
        veZeusContractAddress = _veContractAddress;
        veZeusContract = VeZeusContract(_veContractAddress);
    }

    function initialize(uint256 amount) external {
        address account = msg.sender;
        uint256 _lastInit = lastInit[account];
        uint256 diff = lastRun - _lastInit;
        if(lastRun > 0 && _lastInit > 0){
            require(lastRun > _lastInit && diff >= 60, "Queue:Existing data"); //prevent multiple queing by users
        }
        uint256 waitTime = timeBeforeStaking[account];
        require(block.timestamp >= waitTime + 180, "Interval error"); //User can only trigger staking every 3 minutes
        require(amount >= minDeposit, "min:Amount not within constraint");
        require(account != address(0), "Invalid address");
        uint256 usdcAmount = amount.mul(10**6);
        USDC.transferFrom(account, collector, usdcAmount);
         //ensure user has not exceeded max stake amount
        (,uint256 _amount,) = handlerContract.getLockedFund(account);
        require(_amount+amount <= maxDeposit, "max:Amount not within constraint");
        handlerContract.queue(account, amount);
        timeBeforeStaking[account] = block.timestamp;
        lastInit[account] = block.timestamp;
    }

    function stake(uint256 amount) external {
        address account = msg.sender;
        bool isMember = membershipContract.isMember(account);
        require(isMember, "Not subscribed");
        uint256 zeusAmount = amount.mul(10**18);
        Zeus.transferFrom(account, collector, zeusAmount);
        veZeusContract.stake(account, amount);

    }

    function vote(uint ballotId, uint256 choiceId, uint256 amount) external {
        address account = msg.sender;
        bool isMember = membershipContract.isMember(account);
        require(isMember, "Not subscribed");
        uint256 veZeusAmount = amount.mul(10**18);
        VEZEUS.transferFrom(account, vzeusCollector, veZeusAmount);
        votingContract.vote(account,ballotId,choiceId,amount);
    }

    function cancelTransaction(uint256 _txId) public {
        address account = msg.sender;
        uint256 amount = handlerContract.cancel(_txId, account);
        uint256 usdcAmount = amount.mul(10**6);
        USDC.transferFrom(collector, account, usdcAmount);
    }

    function executeTransaction(uint256[] memory _txIds) public {
        for(uint256 i = 0; i < _txIds.length; i++){
            (address account,) = handlerContract.execute(_txIds[i]);
            membershipContract.subscribe(account);
        }
        lastRun = block.timestamp;
    }

    function updateCollector(address _collector) external onlyAdmin{
        collector = _collector;
    }

    function withdrawUSDC() external {
        address account = msg.sender;
        (uint256 amount, uint256 timestamp) = handlerContract.withdraw(account);
        uint256 usdcAmount = amount.mul(10**6);
        uint256 payableAmount;
        if(block.timestamp < (timestamp + 30 days)) {
            payableAmount = usdcAmount - (lockupPayoutPercentages[0].div(100) * usdcAmount);
        }
        if(block.timestamp >= timestamp.add(30 days) && block.timestamp < timestamp.add(60 days)){
            payableAmount = usdcAmount - (lockupPayoutPercentages[1].div(100) * usdcAmount);
        }
        if(block.timestamp >= timestamp.add(60 days) && block.timestamp < timestamp.add(90 days)){
            payableAmount = usdcAmount - (lockupPayoutPercentages[2].div(100) * usdcAmount);
        }
        if(block.timestamp >= timestamp.add(90 days)){
            payableAmount = usdcAmount;
        }
        
        USDC.transferFrom(collector, account, payableAmount);
        membershipContract.unSubscribe(account);
    }

    function withdrawVEZEUS() external {
        address account = msg.sender;
        uint256 amount = veZeusContract.withdrawVeZeus(account);
        uint256 zeusAmount = amount.mul(10**18);
        VEZEUS.transferFrom(collector, account, zeusAmount);
    }

    function getAccountTransactions(uint256 _txId) view public 
        returns(address _owner, uint256 _amount, uint256 _timestamp){
        return handlerContract.getTransaction(_txId);
    }

    function setCurrentBallotCreator(address _creator) external onlyAdmin {
        currentBallotCreator = _creator;
    }

    function setMaxAndMinDeposit(uint256 max, uint256 min) external onlyAdmin{
        maxDeposit = max;
        minDeposit = min;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }
    modifier ballotCreator(){
        require(msg.sender == admin || msg.sender == currentBallotCreator, "unauthorized");
        _;
    }
}
