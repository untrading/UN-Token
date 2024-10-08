// SPDX-LICENSE-IDENTIFIER: UNLICENSED
pragma solidity ^0.8.19;

import "solmate/tokens/ERC20.sol";
import "solmate/auth/Owned.sol";

contract UN is ERC20, Owned {
    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
        Owned(msg.sender)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }
}
