pragma solidity 0.4.21;
import "./SafeMath.sol";


contract PaymentIntervalContract {
    using SafeMath for uint;

    address private payerAddress;
    address private payeeAddress;
    address private usufructAddress;

    uint private interval;
    uint private paymentAmount;
    uint private payeeWithdrawTime = 0;
    uint private contractStartTime = 0;
    uint private contractEndTime = 0;
    uint private payerBalance = 0;
    uint private payeeBalance = 0;

    ContractStages private currentStage;

    enum ContractStages { Created, InProgress, Terminated }

    mapping(address => mapping(address => bool)) private usufructAuthorised;
    mapping(address => bool) private startContractAuthorised;
    mapping(address => bool) private terminateContractAuthorised;
    mapping(address => mapping(address => bool)) private payerUpdateAuthorised;
    mapping(address => mapping(address => bool)) private payerRemoveAuthorised;
    mapping(address => mapping(address => bool)) private payeeUpdateAuthorised;
    mapping(address => mapping(address => bool)) private payeeRemoveAuthorised;
    mapping(address => mapping(address => bool)) private usufructUpdateAuthorised;
    mapping(address => mapping(address => bool)) private usufructRemoveAuthorised;

    event ContractCreated();
    event ContractStartRequested();
    event ContractStarted();
    event ContractTerminatedRequested();
    event ContractTerminated();

    event FundsDeposited(uint payerBalance);
    event DepositWithdrawn(uint payerBalance);
    event PaymentsWithdrawn(uint payeeBalance);

    event PayerUpdated(address _payerAddress);
    event PayerUpdateRequested(address _payerAddress);
    event PayerUpdateAuthorised(address _payerAddress);
    event PayerRemoveRequested(address _payerAddress);
    event PayerRemoveAuthorised(address _payerAddress);

    event PayeeUpdated(address _payeeAddress);
    event PayeeUpdateRequested(address _payeeAddress);
    event PayeeUpdateAuthorised(address _payeeAddress);
    event PayeeRemoveRequested(address _payeeAddress);
    event PayeeRemoveAuthorised(address _payeeAddress);

    event UsufructUpdateRequested(address usufructAddress);
    event UsufructUpdateAuthorised(address usufructAddress);
    event UsufructRemoveRequested(address usufructAddress);
    event UsufructRemoveAuthorised(address usufructAddress);

    modifier validAddress(address addr) {
        require(addr != address(0x0));
        require(addr != address(this));
        _;
    }

    /// Only the Payer has access to the functionality
    modifier onlyPayer {
        require(msg.sender == payerAddress);
        _;
    }

    /// Only the Payee has access to the functionality
    modifier onlyPayee {
        require(msg.sender == payeeAddress);
        _;
    }

    /// Only the Payer or the Payee have access to the functionality
    modifier payerOrPayee {
        require(msg.sender == payerAddress || msg.sender == payeeAddress);
        _;
    }

    /// Only the Usufruct has access to the functionality
    modifier onlyUsufruct {
        require(msg.sender == usufructAddress);
        _;
    }

    /// Only the Payer, Payee or Usufruct have access to the functionality
    modifier onlyAuthorised {
        require(msg.sender == payerAddress || msg.sender == payeeAddress || msg.sender == usufructAddress);
        _;
    }

    /**
     * Constrctor function
     *
     * Initializes contract with payer, payee, payment interval and payement per interval
     *
     * @param _payerAddress The address of the contract payer
     * @param _payeeAddress The address of the contract payee
     * @param _interval The interval that the payee receives funds
     * @param _paymentAmount The amount of funds to be received per interval
     */
    function PaymentIntervalContract(
        address _payerAddress,
        address _payeeAddress,
        uint _interval,
        uint _paymentAmount
    )
        public
        validAddress(_payerAddress)
        validAddress(_payeeAddress)
    {

        payerAddress = _payerAddress;
        payeeAddress = _payeeAddress;
        interval = _interval;
        paymentAmount = _paymentAmount;
        currentStage = ContractStages.Created;

        emit ContractCreated();
    }

    /**
     * Standard revert function to return accidentally sent Eth
     */
    function () public payable {
        revert();
    }

    /**
     * Deposit funds into the contract by the payer
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

        payerBalance = payerBalance.add(_amount);
        emit FundsDeposited(payerBalance);

        return true;
    }

    /**
     * Withdraw funds from the contract by the payer
     *
     * @param _amount the amount of funds to be withdrawn
     *
     */
    function withdrawFunds(uint _amount)
        public
        onlyPayer
        returns (bool)
    {
        uint currentTime = _getBlockTime();
        uint amountOwning = _calculateUnallocatedFunds(currentTime);

        require(payerBalance.sub(amountOwning) >= _amount);

        payerBalance = payerBalance.sub(_amount);

        _transfer(payerAddress, _amount);
        emit DepositWithdrawn(payerBalance);

        return true;
    }

    /**
     * Withdraw payments made to the payee
     *
     * @param _amount the amount of funds to be withdrawn
     */
    function withdrawPayment(uint _amount)
        public
        onlyPayee
        returns (bool)
    {
        uint currentTime = _getBlockTime();
        uint amountOwning = _calculateUnallocatedFunds(currentTime);

        require(payeeBalance.add(amountOwning) >= _amount);

        payerBalance = payerBalance.sub(amountOwning);
        payeeBalance = payeeBalance.add(amountOwning).sub(_amount);

        payeeWithdrawTime = currentTime;

        _transfer(payeeAddress, _amount);
        emit PaymentsWithdrawn(payeeBalance);

        return true;
    }

    /**
     * Returns current stage of the contract (Created, InProgress, Terminated)
     */
    function getContractState()
        public
        view
        returns (ContractStages)
    {
        return currentStage;
    }

    /**
    * Request that the contract be started
    */
    function startContract()
        public
        onlyAuthorised
        returns (bool)
    {
        require(currentStage == ContractStages.Created);

        startContractAuthorised[msg.sender] = true;
        if (startContractAuthorised[payerAddress] && startContractAuthorised[payeeAddress]) {
            contractStartTime = _getBlockTime();
            currentStage = ContractStages.InProgress;
            emit ContractStarted();
        } else {
            emit ContractStartRequested();
        }

        return true;
    }

    /**
    * Request that the contract be terminated
    */
    function terminateContract()
        public
        onlyAuthorised
        returns (bool)
    {
        require(currentStage == ContractStages.InProgress || currentStage == ContractStages.Created);

        terminateContractAuthorised[msg.sender] = true;
        if (terminateContractAuthorised[payerAddress] && terminateContractAuthorised[payeeAddress]) {
            contractEndTime = _getBlockTime();
            currentStage = ContractStages.Terminated;
            emit ContractTerminated();
        } else {
            emit ContractTerminatedRequested();
        }

        return true;
    }

    /// Returns remaining balance in the payer wallet
    function getPayerBalance() public view returns (uint) {
        uint currentTime = _getBlockTime();
        return payerBalance.sub(_calculateUnallocatedFunds(currentTime));
    }

    /// Returns payer address
    function getPayerAddress() public view returns (address) { return payerAddress; }

    /**
     * Sets new payer address
     *
     * @param _address Address of the new Payer
     */
    function setPayerAddress(address _address)
        public
        onlyPayer
        validAddress(_address)
        returns (bool)
    {
        payerAddress = _address;
        emit PayerUpdated(_address);

        return true;
    }

    /// Removes the payer
    function removePayer() public payerOrPayee returns (bool) {
        payerRemoveAuthorised[_address][msg.sender] = true;
        if (payerRemoveAuthorised[_address][payerAddress] && payerRemoveAuthorised[_address][payeeAddress]) {
            payerAddress = address(0);
            emit PayerRemoveAuthorised(_address);
        } else {
            emit PayerRemoveRequested(_address);
        }

        return true;
    }

    /**
     * Request that the payer be changed
     *
     * @param _address Address of the new Payer
     */
    function requestPayerUpdate(address _address) public payerOrPayee returns (bool) {
        payerUpdateAuthorised[_address][msg.sender] = true;
        if (payerUpdateAuthorised[_address][payerAddress] && payerUpdateAuthorised[_address][payeeAddress]) {
            payerAddress = _address;
            emit PayerUpdateAuthorised(_address);
        } else {
            emit PayerUpdateRequested(_address);
        }

        return true;
    }

    /// Returns remaining balance in the payee wallet
    function getPayeeBalance() public view returns (uint) {
        uint currentTime = _getBlockTime();
        return payeeBalance.add(_calculateUnallocatedFunds(currentTime));
    }

    /// Returns payee address
    function getPayeeAddress() public view returns (address) { return payeeAddress; }

    /**
     * Sets new payee address
     *
     * @param _address Address of the new Payee
     */
    function setPayeeAddress(address _address)
        public
        onlyPayee
        validAddress(_address)
        returns (bool)
    {
        payeeAddress = _address;
        emit PayeeUpdated(_address);

        return true;
    }

    /// Removes the payer
    function removePayee() public payerOrPayee returns (bool) {
        payeeRemoveAuthorised[_address][msg.sender] = true;
        if (payeeRemoveAuthorised[_address][payerAddress] && payeeRemoveAuthorised[_address][payeeAddress]) {
            payeeAddress = address(0);
            emit PayeeRemoveAuthorised(_address);
        } else {
            emit PayeeRemoveRequested(_address);
        }

        return true;
    }

    /**
     * Request that the payee be changed
     *
     * @param _address Address of the new Payee
     */
    function requestPayeeUpdate(address _address) public payerOrPayee returns (bool) {
        payeeUpdateAuthorised[_address][msg.sender] = true;
        if (payeeUpdateAuthorised[_address][payerAddress] && payeeUpdateAuthorised[_address][payeeAddress]) {
            payeeAddress = _address;
            emit PayeeUpdateAuthorised(_address);
        } else {
            emit PayeeUpdateRequested(_address);
        }

        return true;
    }

    /// Returns usufruct address
    function getUsufruct() public view returns (address) { return usufructAddress; }

    /**
     * Request that the usufruct be changed
     *
     * @param _address Address of the new Usufruct
     */
    function requestUsufructUpdate(address _address) public payerOrPayee returns (bool) {
        usufructUpdateAuthorised[_address][msg.sender] = true;
        if (usufructUpdateAuthorised[_address][payerAddress] && usufructUpdateAuthorised[_address][payeeAddress]) {
            usufructAddress = _address;
            emit UsufructUpdateAuthorised(_address);
        } else {
            emit UsufructUpdateRequested(_address);
        }

        return true;
    }

    /**
     * Removes the usufruct
     *
     * @param _address Address of the Usufruct to be removed
     */
    function removeUsufruct(address _address) public payerOrPayee returns (bool) {
        usufructRemoveAuthorised[_address][msg.sender] = true;
        if (usufructRemoveAuthorised[_address][payerAddress] && usufructRemoveAuthorised[_address][payeeAddress]) {
            usufructAddress = address(0);
            emit UsufructRemoveAuthorised(_address);
        } else {
            emit UsufructRemoveRequested(_address);
        }

        return true;
    }

    /**
     * Returns how many interavls there are until the Payer has no more funding
     */
    function getRemainingIntervals()
        public
        view
        returns (uint)
    {
        require(currentStage == ContractStages.InProgress || currentStage == ContractStages.Created);

        uint currentTime = _getBlockTime();
        uint remainingbalance = payerBalance.sub(_calculateUnallocatedFunds(currentTime));

        return remainingbalance.div(paymentAmount);
    }

    /**
     * Transfers the amount of ether to the address specified
     *
     * @param _to Address to transfer ether to
     * @param _amount Amount of ether to transfer
     */
    function _transfer(address _to, uint _amount) internal {
        _to.transfer(_amount);
    }

    /**
     * Calculates how much is currently owed to the payee since the last time that the payee withdrew their funds
     *
     * @param _currentTime the current blockchain time
     */
    function _calculateUnallocatedFunds(uint _currentTime)
        private
        view
        returns (uint)
    {
        uint elapsed = _currentTime.sub(payeeWithdrawTime);
        return paymentAmount.mul(elapsed).div(interval);
    }

    function _getBlockTime()
        private
        view
        returns (uint)
    {
        return block.number.mul(14);
    }

}
