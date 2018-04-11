pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/StandardToken.sol";


/**
 * @title VestingBasicToken
 * @dev Very simple ERC20 Token vesting contract, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `StandardToken` functions.
 */
contract SimpleToken is StandardToken {

    string public constant NAME = "Vesting"; // solium-disable-line uppercase
    string public constant SYMBOL = "VES"; // solium-disable-line uppercase
    uint8 public constant DECIMALS = 18; // solium-disable-line uppercase

    /// 10 000 total tokens
    uint256 public constant INITIAL_SUPPLY = 10000 * (10 ** uint256(DECIMALS));

    /*

    @dev Constructor that gives msg.sender all of existing tokens.

    */
    function SimpleToken() public {
        totalSupply_ = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
        emit Transfer(0x0, msg.sender, INITIAL_SUPPLY);
    }

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
        maxTokenAmountNotReached(amount)
        returns (bool)
    {
        require(_tokenHolder != address(0));
        require(_amount != 0);

        vestedBalances[_tokenHolder] = vestedBalances[_tokenHolder].add(_amount);
        currentSupply = currentSupply.add(_amount);
        return true;
    }
}
