/*

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

*/

/*

@title ERC777 ReferenceToken Contract
@author Jordi Baylina, Jacques Dafflon
@dev This token contract's goal is to give an example implementation
of ERC777 with ERC20 compatible.
This contract does not define any standard, but can be taken as a reference
implementation in case of any ambiguity into the standard

*/

pragma solidity ^0.4.19; /// solhint-disable-line compiler-fixed

import "eip820/contracts/ERC820Implementer.sol";
import "giveth-common-contracts/contracts/Owned.sol";
import "giveth-common-contracts/contracts/SafeMath.sol";
import "./ERC777/ERC20Token.sol";
import "./ERC777/ERC777Token.sol";
import "./ERC777/ERC777TokensSender.sol";
import "./ERC777/ERC777TokensRecipient.sol";

/// Used instead of ERC20Token - Implementation provided in this repo for reference
import "zeppelin-solidity/contracts/token/PausableToken.sol";


contract ReferenceToken is Owned, ERC777Token, ERC820Implementer, PausableToken {
    using SafeMath for uint256;

    string private name;
    string private symbol;
    uint256 private granularity;
    uint256 private totalSupply;
    /// Track current supply for tokens released via vesting
    uint256 public currentSupply;

    bool private erc20compatible;

    mapping(address => uint) private balances;
    mapping(address => mapping(address => bool)) private authorized;
    mapping(address => mapping(address => uint256)) private allowed;

    /// Mapping for vesting balances
    mapping (address => uint) public vestedBalances;
    /// Address for external allowed minter (can instead be onlyOwner)
    address public minter;
    /// Address for external allowed vesting of tokens
    address public vestor;

    /// if external minter is used add onlyMinter
    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    /// if external vestor is used add onlyVestor
    modifier onlyVestor {
        require(msg.sender == vestor);
        _;
    }

    /// Confirm maximum supply has not yet been reached by minting
    modifier maxTokenAmountNotReached (uint amount) {
        require(currentSupply.add(amount) <= totalSupply);
        _;
    }

    /// Boiler plate validation check
    modifier validAddress( address addr ) {
        require(addr != address(0x0));
        require(addr != address(this));
        _;
    }

    /* -- Constructor -- */

    /*

    @notice Constructor to create a ReferenceToken
    @param _name Name of the new token
    @param _symbol Symbol of the new token.
    @param _granularity Minimum transferable chunk.

    */
    function ReferenceToken(
        string _name,
        string _symbol,
        uint256 _granularity
        address _minter
        address _vestor
    )
        public
    {
        require(_granularity >= 1);
        validAddress(_minter)
        validAddress(_vestor)

        name = _name;
        symbol = _symbol;
        totalSupply = 0;
        erc20compatible = true;
        granularity = _granularity;
        minter = _minter;
        vestor = _vestor;

        setInterfaceImplementation("ERC20Token", this);
        setInterfaceImplementation("ERC777Token", this);
    }

    /* -- ERC777 Interface Implementation -- */


    /// @return the name of the token
    function name() public constant returns (string) { return name; }

    /// @return the symbol of the token
    function symbol() public constant returns(string) { return symbol; }

    /// @return the granularity of the token
    function granularity() public constant returns(uint256) { return granularity; }

    /// @return the total supply of the token
    function totalSupply() public constant returns(uint256) { return totalSupply; }

    /*

    @notice Return the account balance of some account
    @param _tokenHolder Address for which the balance is returned
    @return the balance of `_tokenAddress`.

    */
    function balanceOf(address _tokenHolder) public constant returns (uint256) { return balances[_tokenHolder]; }

    /*

    @notice Send `_amount` of tokens to address `_to`
    @param _to The address of the recipient
    @param _amount The number of tokens to be sent

    */
    function send(address _to, uint256 _amount) public {
        doSend(msg.sender, _to, _amount, "", msg.sender, "", true);
    }

    /*

    @notice Send `_amount` of tokens to address `_to` passing `_userData` to the recipient
    @param _to The address of the recipient
    @param _amount The number of tokens to be sent

    */
    function send(address _to, uint256 _amount, bytes _userData) public {
        doSend(msg.sender, _to, _amount, _userData, msg.sender, "", true);
    }

    /*

    @notice Authorize a third party `_operator` to manage (send) `msg.sender`'s tokens.
    @param _operator The operator that wants to be Authorized

    */
    function authorizeOperator(address _operator) public {
        require(_operator != msg.sender);
        authorized[_operator][msg.sender] = true;
        AuthorizedOperator(_operator, msg.sender);
    }

    /*

    @notice Revoke a third party `_operator`'s rights to manage (send) `msg.sender`'s tokens.
    @param _operator The operator that wants to be Revoked

    */
    function revokeOperator(address _operator) public {
        require(_operator != msg.sender);
        authorized[_operator][msg.sender] = false;
        RevokedOperator(_operator, msg.sender);
    }

    /*

    @notice Check whether the `_operator` address is allowed to manage the tokens held by `_tokenHolder` address.
    @param _operator address to check if it has the right to manage the tokens
    @param _tokenHolder address which holds the tokens to be managed
    @return `true` if `_operator` is authorized for `_tokenHolder`

    */
    function isOperatorFor(address _operator, address _tokenHolder) public constant returns (bool) {
        return _operator == _tokenHolder || authorized[_operator][_tokenHolder];
    }

    /*

    @notice Send `_amount` of tokens on behalf of the address `from` to the address `to`.
    @param _from The address holding the tokens being sent
    @param _to The address of the recipient
    @param _amount The number of tokens to be sent
    @param _userData Data generated by the user to be sent to the recipient
    @param _operatorData Data generated by the operator to be sent to the recipient

    */
    function operatorSend(address _from, address _to, uint256 _amount, bytes _userData, bytes _operatorData) public {
        require(isOperatorFor(msg.sender, _from));
        doSend(_from, _to, _amount, _userData, msg.sender, _operatorData, true);
    }

    /* -- ERC20 Compatible Methods -- */


    /*

    @notice This modifier is applied to erc20 obsolete methods that are
    implemented only to maintain backwards compatibility. When the erc20
    compatibility is disabled, this methods will fail.

    */
    modifier erc20 () {
        require(erc20compatible);
        _;
    }

    /*

    @notice Disables the ERC20 interface. This function can only be called
    by the owner.

    */
    function disableERC20() public onlyOwner {
        erc20compatible = false;
        setInterfaceImplementation("ERC20Token", 0x0);
    }

    /*

    @notice Re enables the ERC20 interface. This function can only be called
    by the owner.

    */
    function enableERC20() public onlyOwner {
        erc20compatible = true;
        setInterfaceImplementation("ERC20Token", this);
    }

    /*

    @notice For Backwards compatibility
    @return The decimls of the token. Forced to 18 in ERC777.

    */
    function decimals() public erc20 constant returns (uint8) { return uint8(18); }

    /*

    @notice ERC20 backwards compatible transfer.
    @param _to The address of the recipient
    @param _amount The number of tokens to be transferred
    @return `true`, if the transfer can't be done, it should fail.-

    */
    function transfer(address _to, uint256 _amount) public erc20 returns (bool success) {
        doSend(msg.sender, _to, _amount, "", msg.sender, "", false);
        return true;
    }

    /*

    @notice ERC20 backwards compatible transferFrom.
    @param _from The address holding the tokens being transferred
    @param _to The address of the recipient
    @param _amount The number of tokens to be transferred
    @return `true`, if the transfer can't be done, it should fail.

    */
    function transferFrom(address _from, address _to, uint256 _amount) public erc20 returns (bool success) {
        require(_amount <= allowed[_from][msg.sender]);

        // Cannot be after doSend because of tokensReceived re-entry
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_amount);
        doSend(_from, _to, _amount, "", msg.sender, "", false);
        return true;
    }

    /*

    @notice ERC20 backwards compatible approve.
     `msg.sender` approves `_spender` to spend `_amount` tokens on its behalf.
    @param _spender The address of the account able to transfer the tokens
    @param _amount The number of tokens to be approved for transfer
    @return `true`, if the approve can't be done, it should fail.

    */
    function approve(address _spender, uint256 _amount) public erc20 returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        Approval(msg.sender, _spender, _amount);
        return true;
    }

    /*

    @notice ERC20 backwards compatible allowance.
     This function makes it easy to read the `allowed[]` map
    @param _owner The address of the account that owns the token
    @param _spender The address of the account able to transfer the tokens
    @return Amount of remaining tokens of _owner that _spender is allowed
     to spend

     */
    function allowance(address _owner, address _spender) public erc20 constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    /* -- Helper Functions -- */


    /*

    @notice Internal function that ensures `_amount` is multiple of the granularity
    @param _amount The quantity that want's to be checked

    */
    function requireMultiple(uint256 _amount) internal {
        require(_amount.div(granularity).mul(granularity) == _amount);
    }

    /*

    @notice Check whether an address is a regular address or not.
    @param _addr Address of the contract that has to be checked
    @return `true` if `_addr` is a regular address (not a contract)

    */
    function isRegularAddress(address _addr) internal constant returns(bool) {
        if (_addr == 0) { return false; }
        uint size;
        assembly { size := extcodesize(_addr) } // solhint-disable-line no-inline-assembly
        return size == 0;
    }

    /*

    @notice Helper function actually performing the sending of tokens.
    @param _from The address holding the tokens being sent
    @param _to The address of the recipient
    @param _amount The number of tokens to be sent
    @param _userData Data generated by the user to be passed to the recipient
    @param _operatorData Data generated by the operator to be passed to the recipient
    @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
     implementing `erc777_tokenHolder`.
     ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     functions SHOULD set this parameter to `false`.

    */
    function doSend(
        address _from,
        address _to,
        uint256 _amount,
        bytes _userData,
        address _operator,
        bytes _operatorData,
        bool _preventLocking
    ) private {
        requireMultiple(_amount);
        require(_to != address(0));          // forbid sending to 0x0 (=burning)
        require(balances[_from] >= _amount); // ensure enough funds

        callSender(_operator, _from, _to, _amount, _userData, _operatorData);
        balances[_from] = balances[_from].sub(_amount);
        balances[_to] = balances[_to].add(_amount);

        callRecipient(_operator, _from, _to, _amount, _userData, _operatorData, _preventLocking);
        Sent(_operator, _from, _to, _amount, _userData, _operatorData);

        if (erc20compatible) { Transfer(_from, _to, _amount); }
    }

    /*

    @notice Helper function that checks for ERC777TokensRecipient on the recipient and calls it.
     May throw according to `_preventLocking`
    @param _from The address holding the tokens being sent
    @param _to The address of the recipient
    @param _amount The number of tokens to be sent
    @param _userData Data generated by the user to be passed to the recipient
    @param _operatorData Data generated by the operator to be passed to the recipient
    @param _preventLocking `true` if you want this function to throw when tokens are sent to a contract not
     implementing `ERC777TokensRecipient`.
     ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     functions SHOULD set this parameter to `false`.

    */
    function callRecipient(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes _userData,
        bytes _operatorData,
        bool _preventLocking
    ) private {
        address recipientImplementation = interfaceAddr(_to, "ERC777TokensRecipient");
        if (recipientImplementation != 0) {
          ERC777TokensRecipient(recipientImplementation).tokensReceived(
            _operator, _from, _to, _amount, _userData, _operatorData);
        } else if (_preventLocking) {
          require(isRegularAddress(_to));
        }
    }

    /*

    @notice Helper function that checks for ERC777TokensSender on the sender and calls it.
     May throw according to `_preventLocking`
    @param _from The address holding the tokens being sent
    @param _to The address of the recipient
    @param _amount The amount of tokens to be sent
    @param _userData Data generated by the user to be passed to the recipient
    @param _operatorData Data generated by the operator to be passed to the recipient
     implementing `ERC777TokensSender`.
     ERC777 native Send functions MUST set this parameter to `true`, and backwards compatible ERC20 transfer
     functions SHOULD set this parameter to `false`.

    */
    function callSender(
        address _operator,
        address _from,
        address _to,
        uint256 _amount,
        bytes _userData,
        bytes _operatorData
    ) private {
        address senderImplementation = interfaceAddr(_from, "ERC777TokensSender");
        if (senderImplementation != 0) {
            ERC777TokensSender(senderImplementation).tokensToSend(
              _operator, _from, _to, _amount, _userData, _operatorData);
        }
    }

    /// Vesting implementation

    /*

    @param _tokenHolder The destination account owning tokens that will be vested
    @param _amount The amount of tokens to be vested

    */
    function vest(address _tokenHolder, uint _amount)
        external
        onlyVestor
        returns (bool)
    {
        require(_tokenHolder != address(0));
        require(_amount <= balances[_tokenHolder]);

        balances[_tokenHolder] = balances[_tokenHolder].sub(_amount);
        vestedBalances[_tokenHolder] = vestedBalances[_tokenHolder].add(_amount);
        return true;
    }

    /*

    @param _tokenHolder The destination account that will have their tokens released
    @param amount The amount tokens released from the vesting contract

    */
    function release(address _tokenHolder, uint _amount)
        external
        onlyVestor
        returns (bool)
    {
        require(_tokenHolder != address(0));
        require(_amount <= vestedBalances[_tokenHolder]);

        ///Implementation 1: can do minting here on withdrawal based on how many blocks

        vestedBalances[_tokenHolder] = vestedBalances[_tokenHolder].sub(_amount);
        balances[_tokenHolder] = balances[_tokenHolder].add(_amount);

        return true;
    }

    ///Implementation 2: do minting directly as an external process

    /*

    @param _tokenHolder The destination account that we will mint tokens to
    @param amount The amount tokens minted to the contract

    */
    function mint(address _tokenHolder, uint _amount)
          external
          onlyMinter
          maxTokenAmountNotReached(_amount)
          returns (bool)
      {
          require(_tokenHolder != address(0));
          require(_amount != 0);

          vestedBalances[_tokenHolder] = vestedBalances[_tokenHolder].add(_amount);
          currentSupply = currentSupply.add(_amount);
          return true;
      }
}
