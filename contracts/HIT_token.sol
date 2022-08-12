// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract HITESH is ERC20, AccessControl {
    event Create(address indexed to, uint indexed amount);
    event Approve(uint indexed txId, address indexed approver);
    event Revoke(uint indexed txId, address indexed approver);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FEE_ROLE = keccak256("FEE_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant EXECUTE_ROLE = keccak256("EXECUTE_ROLE");
    bytes32 private constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    uint256 private fee;
    uint private required;
    address[] public roles;
    mapping(address => bool) public roleAddress;

    struct Transaction {
        address from;
        address to;
        uint amount;
        bool executed;
    }

    mapping(uint => mapping(address => bool)) private approval;
    Transaction[] public transactions;

    modifier notApproved(uint _txId) {
        require(
            !approval[_txId][msg.sender],
            "Transaction Already Approved..."
        );
        _;
    }

    modifier existTrans(uint _txId) {
        require(
            _txId <= transactions.length - 1,
            "Transaction Does not Exist..."
        );
        _;
    }

    modifier isNotExec(uint _txId) {
        Transaction memory transaction = transactions[_txId];
        require(!transaction.executed, "Transaction Already Executed");
        _;
    }

    modifier isApproved(uint _txId) {
        require(approval[_txId][msg.sender], "Transaction Not Approved...");
        _;
    }

    constructor(address _to, uint _required) ERC20("HITESH", "HIT") {
        // Send 10% of total supply to address 'to'
        _mint(msg.sender, 1000 * 10**decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        roleAddress[msg.sender] = true;
        roles.push(msg.sender);

        uint amount = totalSupply() / 10;
        super.transfer(_to, amount);

        required = _required;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address _account, uint256 _amount)
        external
        onlyRole(BURNER_ROLE)
    {
        require(balanceOf(_account) >= _amount, "Insufficient Balance....");
        _burn(_account, _amount);
    }

    function setFee(uint token) external onlyRole(FEE_ROLE) {
        fee = token * 10**decimals();
    }

    function getFee() public view returns (uint) {
        return fee;
    }

    // MultiSig for ERC-20

    function canExec(uint _txId) public view returns (uint count) {
        for (uint i; i < roles.length; i++)
            if (approval[_txId][roles[i]]) {
                count += 1;
            }
    }

    function createTransaction(address to, uint amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient Balance");
        Transaction memory transaction = Transaction(
            msg.sender,
            to,
            amount,
            false
        );
        transactions.push(transaction);
        emit Create(to, amount);
    }

    function approveTransaction(uint _txId)
        external
        notApproved(_txId)
        existTrans(_txId)
        onlyRole(DEFAULT_ADMIN_ROLE)
        isNotExec(_txId)
    {
        approval[_txId][msg.sender] = true;
        emit Approve(_txId, msg.sender);
    }

    function revokeApproval(uint _txId)
        external
        isApproved(_txId)
        existTrans(_txId)
        onlyRole(DEFAULT_ADMIN_ROLE)
        isNotExec(_txId)
    {
        approval[_txId][msg.sender] = false;
        emit Revoke(_txId, msg.sender);
    }

    function executeTransaction(uint _txId)
        external
        payable
        existTrans(_txId)
        onlyRole(EXECUTE_ROLE)
        isNotExec(_txId)
    {
        require(canExec(_txId) >= required, "Not Enough Approvals...");
        Transaction storage transaction = transactions[_txId];
        uint total = getFee() + transaction.amount;
        require(
            total <= balanceOf(transaction.from),
            "Insufficient Balance..."
        );
        _transfer(transaction.from, transaction.to, total);
        transaction.executed = true;
    }

    function transfer(address to, uint amount)
        public
        virtual
        override
        returns (bool success)
    {
        require(
            hasRole(SUPER_ADMIN_ROLE, msg.sender),
            "Create a new Transaction..."
        );
        success = super.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool success) {
        require(
            hasRole(SUPER_ADMIN_ROLE, msg.sender),
            "Create a new Transaction..."
        );
        success = super.transferFrom(from, to, amount);
    }

    function grantRole(bytes32 role, address account) public virtual override {
        require(role != SUPER_ADMIN_ROLE, "Cannot grant Super Admin Role");
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not the Admin");
        if (!roleAddress[account]) {
            roleAddress[account] = true;
            roles.push(account);
        }
        _grantRole(role, account);
    }
}
