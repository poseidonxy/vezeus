// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Membership {
    mapping(address => bool) public members;
    address public admin;
    address public messenger;

    event newEvent(string _message);

    constructor() {
        admin = msg.sender;
    }

    function isMember(address member) public view returns (bool) {
        return members[member];
    }

    function subscribe(address member) public middleware {
        members[member] = true;
        emit newEvent("New member subscribed");
    }

    function unSubscribe(address member) public middleware {
        members[member] = false;
        emit newEvent("Member subscribed");
    }

    function setAuthorities(address _messenger)
        external
        middleware
    {
        messenger = _messenger;
    }

    modifier middleware() {
        require(msg.sender == admin || msg.sender == messenger, "Unauthorized");
        _;
    }
}
