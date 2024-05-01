// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@solmate/src/tokens/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory _name, string memory _symbol, uint256 _init_supply) ERC20(_name, _symbol, 18) {
        super._mint(msg.sender, _init_supply);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    // function symbol() public view override returns (string memory) {
        // super.symbol();
    // }
}