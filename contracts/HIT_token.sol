// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

//**** Accounts Needed ****
// Account 1 = Minter, Admin, Sender of transaction
// Account 2 = FEE Role
// Account 3 = Execute Role
// Account 4 = Admin
// Account 5 = Recipient of transaction
// Account 6 = Send 10% Supply 0x09F59a58169B42e426a6398b167128F4AD4cC0dF

/* Openzepplin contracts allow us to import and reuse the 
   codes which provide a specific task. Below, we can see 
   that there are two Contracts imported ERC-20 and AccessControl.
   The ERC-20.sol is used to implement the ERC-20 standard and the 
   functions and AccessControl.sol is used to implement the Roles 
   and Accessibility functionlaity to the Smart Contract
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract HITESH is ERC20, AccessControl {  
    
    //**** Declaring some events which are going to trigger after a certain event has been emitted ****

    event Create(address indexed to, uint indexed amount);          // Create event is triggered when a new transaction is created
    event Approve(uint indexed txId, address indexed approver);     // Approve event is triggered when an existing transaction is approved
    event Revoke(uint indexed txId, address indexed approver);      // Revoke event is triggered when an approved transaction is revoked approval

    //**** AccessControl allows us to declare roles which can be used to provide privelages to the Smart Contract for certain addresses (5 Roles) ****

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");             // An address with Minter Role can mint new tokens thus increasing the Total Supply
    bytes32 public constant FEE_ROLE = keccak256("FEE_ROLE");                   // An address with Fee Role is given authority to Set Fees of the transactions
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");             // An address with Burner Role is given authority to Burn existing tokens thus decreasing the Total Supply
    bytes32 public constant EXECUTE_ROLE = keccak256("EXECUTE_ROLE");           // An address with Execute Role is given authority to execute approved transactions which have an approval >= required apporval 
    bytes32 private constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");  // An address with Super Admin Role can call special functions, but this Role is not assigned to any address

    //**** Some state variables are defined below ****

    uint256 private fee;                                        // Stores the fees set by the FEE_ROLE address
    uint private required;                                      // Stores the minimum required approvals for a transaction
    address[] public roles;                                     // Stores the addresses of accounts assigned a Role
    mapping(address => bool) public roleAddress;                // Mapping of address with a role to either true or flase
    mapping(uint => mapping(address => bool)) private approval; // Double mapping of Transaction Id(uint) to address which approves it to either true or false


    //**** Declaring a structure for Transactions ****

    struct Transaction {        
        address from;          // Sender's address
        address to;            // Recipient's address
        uint amount;           // Amount sent
        bool executed;         // To check whether the transaction is executed or not
    }

    Transaction[] public transactions; // Declaring an array to store transactions

    //**** Declaring modifiers ****.
    // Modifiers are blocks of code which are declared with function signature and are used to perform must needed operations to modify the behaviour of a function

    modifier notApproved(uint _txId) {                      // Modifer to check if the transaction of txId is not yet approved by the caller of the function
        require(
            !approval[_txId][msg.sender],
            "Transaction Already Approved..."
        );
        _;
    }

    modifier existTrans(uint _txId) {                       // Modifier to check if the transaction with the txId exists or not
        require(
            _txId <= transactions.length - 1,
            "Transaction Does not Exist..."
        );
        _;
    }

    modifier isNotExec(uint _txId) {                        // Modifier to check if the transaction with the txId is executed or not
        Transaction memory transaction = transactions[_txId];
        require(!transaction.executed, "Transaction Already Executed");
        _;
    }

    modifier isApproved(uint _txId) {                       // Modifier to check if the transaction with the txId is already approved
        require(approval[_txId][msg.sender], "Transaction Not Approved...");
        _;
    }

    //**** Constructor is the entry point of the Smart Contract ****
    // The Constructor takes address and uint as input. The address is to specify the destination to send 10% of Total Supply and uint is to specify the required apporvals for transactions
    
    constructor(address _to, uint _required) ERC20("HITESH", "HIT") {  // Name of Token: HITESH , Symbol: HIT
    
        _mint(msg.sender, 1000 * 10**decimals());           // Total Supply: 1000 tokens , Decimals: 18
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);         // Granting Admin Role to the deployer
        _grantRole(MINTER_ROLE, msg.sender);                // Granting Minter Role to the deployer
        roleAddress[msg.sender] = true;                     
        roles.push(msg.sender);

        // Send 10% of total supply to address 'to'
        uint amount = totalSupply() / 10;
        super.transfer(_to, amount);

        required = _required;                               // Assigning the minimum required approvals for a trnsaction
    }

    //**** Some useful functions ****

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) { // Takes address of recipient and amount of tokens to be minted. Only the address with Minter Role can call this function
        _mint(to, amount);                                                   // _mint is inherited from ERC20.sol to mint new tokens
    }

    function burn(address _account, uint256 _amount)                         // Takes address of account and amount of tokens to be burned. Only the address with Burner Role can call this function
        external
        onlyRole(BURNER_ROLE)
    {
        require(balanceOf(_account) >= _amount, "Insufficient Balance...."); // Checking if the account has sufficient balance before burning tokens
        _burn(_account, _amount);                                            // _burn is inherited from ERC20.sol to burn existing tokens from an account
    }       

    function setFee(uint token) external onlyRole(FEE_ROLE) {                // Takes the amount of tokens as input and sets them to the fee value. Only the address with Fee Role can call this function
        fee = token * 10**decimals();
    }

    function getFee() public view returns (uint) {                           // Returns the fee value
        return fee;
    }

    //**** Declaring functions for MultiSig functionality ****

    function canExec(uint _txId) public view returns (uint count) {         // Returns the count of approvals on a transaction. Function is used to check if the transaction is eligible to execute
        for (uint i; i < roles.length; i++)
            if (approval[_txId][roles[i]]) {
                count += 1;
            }
    }

    function createTransaction(address to, uint amount) external {          // This function takes recipients adress, amount and creates a new Transaction and stores it in transactions array
        require(balanceOf(msg.sender) >= amount, "Insufficient Balance");   // To check if the sender has sufficient balance
        Transaction memory transaction = Transaction(
            msg.sender,
            to,
            amount,
            false
        );
        transactions.push(transaction);
        emit Create(to, amount);                                            // Emitting Create event
    }

    function approveTransaction(uint _txId)                                 // This function takes the Transaction Id as an input and approves the transaction only if :
        external                                                            // the transaction is not yet approved, the transaction exists, function is called by Admin and transaction is not yet executed
        notApproved(_txId)
        existTrans(_txId)
        onlyRole(DEFAULT_ADMIN_ROLE)
        isNotExec(_txId)
    {
        approval[_txId][msg.sender] = true;
        emit Approve(_txId, msg.sender);                                    // Emitting Approve event
    }

    function revokeApproval(uint _txId)                                     // This function takes Transaction Id as an input and revokes the approval to the transaction only if:
        external                                                            // the transaction is already approved, transaction exists, function is called by Admin and is not yet executed
        isApproved(_txId)
        existTrans(_txId)
        onlyRole(DEFAULT_ADMIN_ROLE)
        isNotExec(_txId)
    {
        approval[_txId][msg.sender] = false;
        emit Revoke(_txId, msg.sender);                                     // Emitting Revoke event
    }

    function executeTransaction(uint _txId)                                 // This function takes Transaction Id as an input and executes the transaction with the corresponding txId only if:
        external                                                            // the transaction exists, function is called by Execute Role and transaction is not yet executed
        payable 
        existTrans(_txId)
        onlyRole(EXECUTE_ROLE)
        isNotExec(_txId)
    {
        require(canExec(_txId) >= required, "Not Enough Approvals...");     // To check if the transactions has minimum approvals for execution
        Transaction storage transaction = transactions[_txId];
        uint total = transaction.amount - getFee();                         // The net amount sent to the recipient
        require(
            transaction.amount + getFee() <= balanceOf(transaction.from),   // To check if sender has sufficient balance
            "Insufficient Balance..."
        );
        _transfer(transaction.from, transaction.to, total);
        transaction.executed = true;                                        // Executed is set to true if transaction is executed successfully
    }

    //**** Overriding some ERC-20 functions ****

    function transfer(address to, uint amount)                                  // transfer function allows to transfer from msg.sender to recipient. This function can only be called by Super Admin Role
        public
        virtual
        override
        returns (bool success)
    {
        require(
            hasRole(SUPER_ADMIN_ROLE, msg.sender),                          
            "Create a new Transaction..."
        );
        success = super.transfer(to, amount);                                   // Calling the parent transfer from ERC-20.sol
    }

    function transferFrom(                                                      // transferFrom function allows to transfer from 'from' to recipient. This function can only be called by Super Admin Role
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool success) {
        require(
            hasRole(SUPER_ADMIN_ROLE, msg.sender),
            "Create a new Transaction..."
        );
        success = super.transferFrom(from, to, amount);                         // Calling the parent transferFrom from ERC-20.sol
    }

    function grantRole(bytes32 role, address account) public virtual override { // grantRole function grants role to addresses. This function can only be called by Admin and not allowed to grant Super Admin Role
        require(role != SUPER_ADMIN_ROLE, "Cannot grant Super Admin Role");
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not the Admin");
        if (!roleAddress[account]) {
            roleAddress[account] = true;
            roles.push(account);
        }
        _grantRole(role, account);                                              // Calling the _grantRole internal function
    }
}
