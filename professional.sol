// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import 'ERC20.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract proffesional is ERC20("Proffesional", "PROFI") {
    constructor() {
        _mint(msg.sender, 1_000_000 * 10**decimals());
        
        address tom;
        address max;
        address jack;

        _transfer(msg.sender, tom, 200_000 * 10**decimals());
        _transfer(msg.sender, max, 300_000 * 10**decimals());
        _transfer(msg.sender, jack, 400_000 * 10**decimals());
    }

    function decimals() public pure override returns(uint8) {
        return 6;
    }

    function _mintReferal() internal { 
        _mint(msg.sender, 100 * 10**decimals());
    }

    function _transferToken(address from, address to, uint256 amount) internal {
        _transfer(from, to, amount);
    }
}