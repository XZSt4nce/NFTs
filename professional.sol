// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "ERC20.sol";

contract proffesional is ERC20("Proffesional", "PROFI") {
    constructor() {
        address tom = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        address max = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
        address jack = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;

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