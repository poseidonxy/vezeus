// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Vote {
    address public messenger;
    struct Choice {
        uint256 id;
        string name;
        uint256 votes;
    }
    struct Ballot {
        uint256 id;
        string name;
        Choice[] choices;
        uint256 end;
    }
    mapping(uint256 => Ballot) public ballots;
    uint256 public nextBallotId;
    address public admin;
    mapping(address => mapping(uint256 => uint256)) public votes;
    event newEvent(string _message);

    constructor() {
        admin = msg.sender;
    }

    function getBallot(uint256 id) external view returns (Ballot memory) {
        return ballots[id];
    }

    function getVote(uint256 _ballotId, address account) external view returns (uint256) {
        return votes[account][_ballotId];
    }

    function createBallot(
        string memory name,
        string[] memory _choices,
        uint256 offset
    ) public middleware {
        ballots[nextBallotId].id = nextBallotId;
        ballots[nextBallotId].name = name;
        ballots[nextBallotId].end = block.timestamp + offset;
        for (uint256 i = 0; i < _choices.length; i++) {
            ballots[nextBallotId].choices.push(Choice(i, _choices[i], 0));
        }
        nextBallotId++;
        emit newEvent("Ballot created successfully");
    }

    function vote(address account, uint256 ballotId, uint256 choiceId, uint256 amount) external middleware{
        require(block.timestamp < ballots[ballotId].end, "voting ended");
        votes[account][ballotId] += amount;
        ballots[ballotId].choices[choiceId].votes += amount;
        emit newEvent("Your vote has been counted");
    }

    function results(uint256 ballotId) external view returns (Choice[] memory) {
        require(
            block.timestamp >= ballots[ballotId].end,
            "cannot see the ballot result before ballot end"
        );
        return ballots[ballotId].choices;
    }

    function setAuthorities(address _messenger)
        external
        middleware
    {
        messenger = _messenger;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }
    modifier middleware() {
        require(msg.sender == admin || msg.sender == messenger, "Unauthorized");
        _;
    }
}
