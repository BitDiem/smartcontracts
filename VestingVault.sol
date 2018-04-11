pragma solidity ^0.4.11;

import "../zeppelin/contracts/math/SafeMath.sol";
import "../zeppelin/contracts/ownership/Ownable.sol";

/*

  Vesting Vault is a storing prototype, users can send funds to the vault, it will keep their funds
  they can withdraw funds whenever they require, vesting only occurs on non withdrawn funds.
  
  The contract implements TokenRecipient, a light weight ERC821 implementation specific for BitDiem tokens


*/
contract VestingVault is Ownable, TokenRecipient {
    using SafeMath for uint256;

    mapping (address => uint256) public vested;
    address public wallet;

    function deposit(address _vestor, _amount) {
        vested[_vestor] = _vestor[_vestor].add(_amount);
    }

}