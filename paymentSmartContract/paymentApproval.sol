pragma solidity ^0.4.16;

contract PaymentApprovalContract {

    address public payer;
    address public payee;
    uint public paymentAmount;
    Stages private currentStage;

    mapping(address => uint) public balances;

    enum Stages { Created, Approved, Terminated }


    modifier validAddress( address addr ) {
        require(addr != address(0x0));
        require(addr != address(this));
        _;
    }
    modifier onlyPayer {
        require(msg.sender == payer);
        _;
    }
    modifier onlyPayee {
        require(msg.sender == payee);
        _;
    }
    modifier payerOrPayee {
        require(msg.sender == payer || msg.sender == payee);
        _;
    }

    /**
     * Constrctor function
     *
     * Initializes contract with payer, payee, payment interval and payement per interval
     *
     * @param _name The token name
     * @param _symbol The token symbol
     * @param _payer The address of the contract payer
     * @param _payee The address of the contract payee
     * @param _interval The interval that the payee receives funds
     * @param _paymentAmount The amount of funds to be received per interval
     */
    function PaymentApprovalContract(
        address _payer,
        address _payee,
        uint _paymentAmount
    )
        public
        validAddress(payer)
        validAddress(payee)
    {

        payer = _payer;                                 // Set the payer of the contract
        payee = _payee;                                 // Set the payee of the contract
        paymentAmount = _paymentAmount;                 // Set the amount of funds to be transfered per interval of the contract

        balances[payer] = 0;
        balances[payee] = 0;

        currentStage = Stages.Created;
    }


    /**
     * Deposit funds into the contract for payment
     *
     * @param _amount the amount of funds to be depositted
     */
    function depositFunds(uint _amount)
        public
        payable
        onlyPayer
        returns (bool)
    {
        require(msg.value == _amount);

        balances[msg.sender] = balances[msg.sender] + _amount;

        return true;
    }


    /**
     * Withdraw funds from the contract for payment
     *
     * @param _amount the amount of funds to be withdrawn
     */
    function withdrawFunds(uint _amount)
        public
        payable
        payerOrPayee
        returns (bool)
    {
        uint totalBalance = balances[msg.sender];

        if(msg.sender == payer) {
            totalBalance = balances[msg.sender] - paymentAmount;
        }
 
        if(totalBalance >= _amount) {
            balances[msg.sender] = balances[msg.sender] - _amount;

            _transfer(msg.sender, _amount);
            return true;
        } else {
            return false;
        }
    }


    /**
     * Transfers the amount of ether to the address specified
     *
     * @param _to Address to transfer ether to
     * @param _amount Amount of ether to transfer
     */
    function _transfer(address _to, uint _amount) internal returns (bool) {
        _to.transfer(_amount);
    }


    /**
    * Approves the payment process so that the payee can receive funds
    */
    function approveContract()
        public
        onlyPayer
        returns (bool)
    {
        require(currentStage == Stages.Created);
        require(balances[payer] >= paymentAmount);

        balances[payee] = balances[payee] + paymentAmount;
        currentStage = Stages.Approved;
        return true;
    }


    /**
    * Terminates the payment process so that the contract is void
    */
    function terminateContract()
        public
        payerOrPayee
        returns (bool)
    {
        require(currentStage == Stages.Started);

        currentStage = Stages.Terminated;
        return true;
    }

}
