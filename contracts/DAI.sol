pragma solidity ^0.5.2;
import "./StandardToken.sol";

contract DAI is StandardToken {
    string private _symbol = "DAI";
    uint8 private _decimals = 18;
    uint256 public _maxSupply = 3000000000000000000000000;

    constructor() public {
       totalSupply = 300000000000000000000000;
       _balances[0xB440ea2780614b3c6a00e512f432785E7dfAFA3E] = 100000000000000000000000;
       _balances[0x4AD56641C569C91C64C28a904cda50AE5326Da41] = 100000000000000000000000;
       _balances[0x362ea687b8a372a0235466a097e578d55491d37f] = 100000000000000000000000;
    }

    function symbol() public view returns (string memory){
        return _symbol;
    }

    function decimals() public view returns (uint8){
        return _decimals;
    }
}
