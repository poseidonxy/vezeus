// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

abstract contract VeZeusDataContract {
    function getData(address account)
        external
        view
        virtual
        returns (
            uint256,
            uint256,
            uint256
        );

    function setData(address account, uint256 amount) external virtual;

    function updateTime(address account) external virtual;
}

abstract contract HandlerContract {
    function getLockedFund(address account)
        external
        view
        virtual
        returns (
            address _owner,
            uint256 _amount,
            uint256 _timestamp
        );
}

contract VeZeus {
    using SafeMath for uint256;

    address public admin;
    address public middlewareContractAddress;
    address public veDataContractAddress;
    address public handlerContractAddress;
    address public collector = 0x67dD4EA99CE6453f28DA3b08d0257063189121e6;
    VeZeusDataContract veZeusDataContract;
    HandlerContract handlerContract;
    uint256 public rate = 28000000000000;

    //deploy veDataContract and the handler contract first

    constructor(address _veDataContractAddress, address _handlerContractAddress)
    {
        admin = msg.sender;
        veZeusDataContract = VeZeusDataContract(_veDataContractAddress);
        handlerContract = HandlerContract(_handlerContractAddress);
        handlerContractAddress = _handlerContractAddress;
        veDataContractAddress = _veDataContractAddress;
    }

    function setMiddlewareAddress(address _middlewareContractAddress)
        external
        middleware
    {
        middlewareContractAddress = _middlewareContractAddress;
    }

    function setAddresses(
        address _veDataContractAddress,
        address _handlerContractAddress
    ) external middleware {
        handlerContractAddress = _handlerContractAddress;
        veDataContractAddress = _veDataContractAddress;
        veZeusDataContract = VeZeusDataContract(_veDataContractAddress);
        handlerContract = HandlerContract(_handlerContractAddress);
    }

    function stake(address account, uint256 amount) external middleware {
        veZeusDataContract.setData(account, amount);
    }

    function profitPerSecond(address account) public view returns (uint256) {
        (uint256 zeusStaked, , uint256 lastclaimTime) = veZeusDataContract
            .getData(account);
        (, uint256 usdcStaked, ) = handlerContract.getLockedFund(account);
        uint256 claimTime = block.timestamp.sub(lastclaimTime);
        uint256 hourlyProfit = (claimTime * rate * usdcStaked * zeusStaked).div(3600);
        return hourlyProfit.div(60);
    }

    function withdrawVeZeus() external middleware returns (uint256) {
        address account = msg.sender;
        uint256 amount = profitPerSecond(account);
        veZeusDataContract.updateTime(account);
        return amount;
    }

    modifier middleware() {
        require(
            msg.sender == admin || msg.sender == middlewareContractAddress,
            "Unauthorized"
        );
        _;
    }
}
