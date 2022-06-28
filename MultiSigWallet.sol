pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

contract MultisigWallet {
    uint private requiredApprovals;

    address[] public ownersAddress;
    mapping(address => uint) accountBalance; //Address of user points to balance of user;

    mapping(address => mapping(uint => bool)) approvals; //Address of user points to specific transfer request and decides whether to approve or not e.g. mapping[msg.sender][5] = true;

    struct transferRequest {
        uint ID;
        uint amount;
        address sender;
        address recipient;
        bool hasBeenSent;
        uint currentApprovalNumber;
    }
    
    transferRequest[] transferRequests; //Store each transfer request. Perhaps delete them once transfer has been approved and sent.

    event depositDone(uint amount, address indexed depositedTo);
    event TransferApproved(uint _id, string message);

    constructor(address[] memory accounts, uint approvalAmount) {
        ownersAddress = accounts;
        requiredApprovals = approvalAmount;
    }

    function deposit() public payable returns (uint)  {
        accountBalance[msg.sender] += msg.value;
        emit depositDone(msg.value, msg.sender);  
        return accountBalance[msg.sender];
    }

    function withdraw(uint amount) public returns (uint){
        require(accountBalance[msg.sender] >= amount);
        accountBalance[msg.sender] -= amount;
        msg.sender.transfer(amount);
        return accountBalance[msg.sender];
    }
    
    function getBalance() public view returns (uint){
        return accountBalance[msg.sender];
    }

   //Should only allow people in the owners list to continue the execution.
    modifier onlyOwners() {
        bool owner = false;

        for(uint i = 0; i < ownersAddress.length; i++)
        {
            if(ownersAddress[i] == msg.sender)
            {
                owner = true;
            }
        }
        require(owner == true);
        _;
    }

    function requestTransfer(address recipient, uint amount) public onlyOwners {
        require(accountBalance[msg.sender] >= amount, "Balance not sufficient");
        require(msg.sender != recipient, "Don't transfer money to yourself");

        transferRequest memory transferObject = transferRequest(transferRequests.length, amount, msg.sender, recipient, false, 0);
        transferRequests.push(transferObject);
    }

    function getTransfer(uint id) public view returns (uint amount) {
        return transferRequests[id].amount;
    }
    
    function transferAmount(uint transferID) private {

        uint previousSenderBalance = accountBalance[transferRequests[transferID].sender];
            
        _transfer(transferRequests[transferID].sender, transferRequests[transferID].recipient, transferRequests[transferID].amount);
                    
        assert(accountBalance[transferRequests[transferID].sender] == previousSenderBalance - transferRequests[transferID].amount);

        //Delete completed transfer.
       // delete transferRequests[transferID];
       // delete approvals[transferRequests[transferID].sender][transferID];

    }
    
    function _transfer(address from, address to, uint amount) private {
        accountBalance[from] -= amount;
        accountBalance[to] += amount;
    }

    function approveTransferRequest(uint _transferID, bool approvalDecision) public onlyOwners {
        require(approvals[msg.sender][_transferID] == false, "Cannot approve the same transfer twice.");
        require(transferRequests[_transferID].hasBeenSent == false);

        approvals[msg.sender][_transferID] = approvalDecision;

        if(approvalDecision == true)
            transferRequests[_transferID].currentApprovalNumber ++;
        else
            transferRequests[_transferID].currentApprovalNumber --;

        if(transferRequests[_transferID].currentApprovalNumber >= requiredApprovals)
        {
            transferAmount(_transferID);
            transferRequests[_transferID].hasBeenSent = approvalDecision;
            emit TransferApproved(_transferID, "Transfer complete");
        }
    }

    //Should return all transfer requests
    function getTransferRequests() public view returns (transferRequest[] memory){
        return transferRequests;
    }
}