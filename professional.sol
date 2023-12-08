// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "ERC20.sol";

contract proffesional is ERC20("Proffesional", "PROFI") {
    constructor() {
        address tom = 0x0Bc37Ab3FcAfafb8ff50d170f8252e1218ec8be9;
        address max = 0x63CE638501e1d1C58b74a9BD2cf521967F5CaF3c;
        address jack = 0x2BaEA19d49bF26Cbc03bEC95B9EAD891DD624f2d;

        _mint(msg.sender, 100_000 * 10**decimals());
        _mint(tom, 200_000 * 10**decimals());
        _mint(max, 300_000 * 10**decimals());
        _mint(jack, 400_000 * 10**decimals());
    }

    function decimals() public pure override returns(uint8) {
        return 6;
    }

    function mintReferal(address wallet) public { 
        _mint(wallet, 100 * 10**decimals());
    }

    function transferToken(address from, address to, uint256 amount) public {
        _transfer(from, to, amount);
    }
}