// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts@4.6.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.6.0/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.6.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.6.0/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts@4.6.0/token/ERC20/extensions/ERC20Votes.sol";

contract TokenBot is
    ERC20,
    ERC20Burnable,
    Ownable,
    ERC20Permit,
    ERC20Votes
{
    uint256 public immutable MAX_SUPPLY = 1000000000 * 10 ** decimals();
    constructor()
        ERC20("TokenBot", "TKB")
        ERC20Permit("TokenBot")
    {}

    function mint(
        address to,
        uint256 amount
    ) public onlyOwner {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "TokenBot::mint: mint amount exceeds MAX_SUPPLY"
        );
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
