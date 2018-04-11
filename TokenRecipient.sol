pragma solidity ^0.4.11;

/*

 Very basic token received implementation. The current constraint with contracts are
 that they are not notified when a contract increments their own balance. This happens because
 the function call isn't executing on the contract, but rather balance transfer simply happens
 in the original contract. This is why a token transfer won't trigger the payable function in
 Ethereum, because ERC20 tokens are first class citizens of the project

*/

contract TokenRecipient {

    /* Implementation listener to be made ware of a token received and who sent it */
    function tokenReceived(address sender, uint256 _value, bytes _extraData) returns (bool) {}

}