pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/token/StandardToken.sol";


/**
 * @title VestingBasicToken
 * @dev Very simple ERC20 Token vesting contract, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `StandardToken` functions.
 */
contract SimpleToken is StandardToken {

    string public name; // solium-disable-line uppercase
    string public symbol; // solium-disable-line uppercase
    uint8 public decimals; // solium-disable-line uppercase

    /// Address to balances mapping for vesting accounts
    mapping (address => uint) public vestedBalances;
    /// Address for external allowed minter (can instead be onlyOwner)
    address public minter;
    /// Address for external allowed vesting of tokens
    address public vestor;

    modifier onlyMinter {
        require(msg.sender == minter);
        _;
    }

    /// if external vestor is used add onlyVestor
    modifier onlyVestor {
        require(msg.sender == vestor);
        _;
    }

    /// Boiler plate validation check
    modifier validAddress( address addr ) {
        require(addr != address(0x0));
        require(addr != address(this));
        _;
    }

    /*

    @dev Constructor that gives msg.sender all of existing tokens.

    */
    function SimpleToken(
        string _name
        string _symbol
        string _decimals
        uint256 _initialSupply
        address _minter
        address _vestor
    ) public {
        name = _name
        symbol = _symbol
        decimals = _decimals
        minter = _minter
        vestor = _vestor
        totalSupply = _initialSupply * (10 ** uint256(decimals));
        balances[msg.sender] = totalSupply;
        emit Transfer(0x0, msg.sender, totalSupply);
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
