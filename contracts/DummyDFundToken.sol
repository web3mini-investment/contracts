// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// this token is used for test CollectiveInvestmentSchemeV2
contract DummyDFundToken is ERC20, Ownable {
    constructor()
        ERC20("DFundToken", "DFN")
        Ownable()
    {
    }

    function mint(uint amount_) external onlyOwner {
        super._mint(owner(), amount_);
    }
}
