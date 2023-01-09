// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Handler {
    error TimestampNotInRangeError(
        uint256 blockTimestamp,
        uint256 timestamp,
        string message
    );
    struct Transaction {
        address owner;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Transaction) public queued;
    mapping(address => uint256[]) public accountTransactions;
    mapping(address => mapping(uint256 => bool)) public transactionStatus;
    mapping(address => Transaction) public lockedFunds;
    address public admin;
    address public messenger;
    address public caller;
    uint256 public transactionId;
    uint256[] public pendingTransactions;
    uint256 public waitingTime = 60; //1 minute pending time

    event newEvent(string _message);
    event Queue(
        uint256 indexed txId,
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    event Execute(
        uint256 indexed txId,
        address indexed owner,
        uint256 amount,
        uint256 timestamp
    );
    event Cancel(uint256 indexed txId);

    constructor() {
        admin = msg.sender;
    }

    function getLockedFund(address account)
        external
        view
        returns (
            address _owner,
            uint256 _amount,
            uint256 _timestamp
        )
    {
        Transaction memory transaction = lockedFunds[account];
        return (transaction.owner, transaction.amount, transaction.timestamp);
    }

    function getTransaction(uint256 _txId)
        external
        view
        returns (
            address _owner,
            uint256 _amount,
            uint256 _timestamp
        )
    {
        Transaction memory transaction = queued[_txId];
        return (transaction.owner, transaction.amount, transaction.timestamp);
    }

    function findIndex(uint256 value, uint256[] memory array)
        internal
        pure
        returns (uint256)
    {
        uint256 i = 0;
        while (array[i] != value) {
            i++;
        }
        return i;
    }

    function queue(address _owner, uint256 _amount)
        external
        middleware
        returns (uint256 txId)
    {
        uint256 _timestamp = block.timestamp;
        txId = transactionId;
        queued[transactionId] = Transaction(_owner, _amount, _timestamp);
        pendingTransactions.push(transactionId);
        accountTransactions[_owner].push(transactionId);
        transactionStatus[_owner][transactionId] = true;
        transactionId++;
        emit Queue(txId, _owner, _amount, _timestamp);
        return txId;
    }

    function cancel(uint256 _txId, address _owner)
        external
        middleware
        returns (uint256)
    {
        // mapping(uint256 => Transaction) public queued;
        Transaction memory transaction = queued[_txId];
        uint256 delay = transaction.timestamp + waitingTime;
        require(transaction.owner == _owner, "Not owner");
        require(block.timestamp < delay, "Time elapsed");
        // uint256[] memory transactions = accountTransactions[_owner];
        bool isPending = transactionStatus[_owner][_txId];
        require(isPending, "Transaction already executed");
        delete queued[_txId];
        transactionStatus[_owner][_txId] = false;

        //remove from pendingTransactions
        uint256 _p_index = findIndex(_txId, pendingTransactions);
        pendingTransactions[_p_index] = pendingTransactions[
            pendingTransactions.length - 1
        ];
        pendingTransactions.pop();
        //remove from accountTransactions
        uint256 _index = findIndex(_txId, accountTransactions[_owner]);
        accountTransactions[_owner][_index] = accountTransactions[_owner][
            accountTransactions[_owner].length - 1
        ];
        accountTransactions[_owner].pop();
        emit Cancel(_txId);
        return transaction.amount;
    }

    function setWaitingTime(uint256 _time) external onlyAdmin {
        waitingTime = _time;
    }

    function execute(uint256 _txId)
        external
        middleware
        returns (address, uint256)
    {
        uint256 _p_index = findIndex(_txId, pendingTransactions);
        Transaction memory transaction = queued[_txId];
        uint256 delay = transaction.timestamp + waitingTime;
        if (block.timestamp > delay) {
            pendingTransactions[_p_index] = pendingTransactions[
                pendingTransactions.length - 1
            ];
            pendingTransactions.pop();
            delete queued[_txId];
            transactionStatus[transaction.owner][_txId] = false;
        }
        lockedFunds[transaction.owner] = Transaction(
            transaction.owner,
            transaction.amount + lockedFunds[transaction.owner].amount,
            block.timestamp
        );
        return (transaction.owner, transaction.amount);
    }

    function withdraw(address account) external returns (uint256, uint256) {
        Transaction memory transaction = lockedFunds[account];
        require(transaction.owner == account, "Account mismatch");
        delete lockedFunds[account];
        return (transaction.amount, transaction.timestamp);
    }

    function getPendingTransactions() external view returns(uint256[] memory){
        return pendingTransactions;
    }

    function setAuthorities(address _messenger, address _caller)
        external
        onlyAdmin
    {
        messenger = _messenger;
        caller = _caller;
    }

    modifier middleware() {
        require(
            msg.sender == admin ||
                msg.sender == messenger ||
                msg.sender == caller,
            "Unauthorized"
        );
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }
}
