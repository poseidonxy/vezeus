// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract VeZeusData {
    address public admin;
    address public veZeusContractAddress;

    struct Data {
        uint256 amount;
        uint256 time;
        uint256 lastclaimTime;
    }
    mapping(address => Data) public accountBalances;

    constructor() {
        admin = msg.sender;
    }

    function updateVeZeusContractAddress(address _veZeusContractAddress) external middleware {
        veZeusContractAddress = _veZeusContractAddress;
    }

    function setData(address account, uint256 amount) external middleware {
        Data memory accountBalance = accountBalances[account];
        accountBalance.amount += amount;
        accountBalance.time = block.timestamp;
        accountBalance.lastclaimTime = block.timestamp;
        accountBalances[account] = accountBalance;
    }

    function getData(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        Data memory accountBalance = accountBalances[account];
        return (
            accountBalance.amount,
            accountBalance.time,
            accountBalance.lastclaimTime
        );
    }

    function updateTime(address account) external {
        Data memory accountBalance = accountBalances[account];
        accountBalance.lastclaimTime = block.timestamp;
        accountBalances[account] = accountBalance;
    }

    modifier middleware() {
        require(msg.sender == admin || msg.sender == veZeusContractAddress, "Unauthorized");
        _;
    }
}
