// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract MartianColony is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant Manager = keccak256("Manager");
    bytes32 public constant Team = keccak256("Team");
    bytes32 public constant PreSaleList = keccak256("PreSaleList");

    // Define starting values for contract
    bool public SaleIsActive = false;
    bool public PreSaleIsActive = false;

    string public baseURI;

    uint256 public SalePrice = 0.18 ether;
    uint256 public PreSalePrice = 0.12 ether;

    uint256 public constant maxTeamPurchase = 10;
    uint256 public constant maxPreSalePurchase = 3;

    uint256 public constant Max_Martians = 11111;
    uint256 public constant Max_Team_Martians = 111;
    uint256 public constant Max_PreSale_Martians = 2222;

    uint256 public TeamSupply = 0;
    uint256 public PreMintedSupply = 0;

    constructor() ERC721("Martian Colony", "MC1") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(Manager, msg.sender);
    }

    // Withdraw contract balance to creator (mnemonic seed address 0)
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    // Set a new base metadata URI to be used for all NFTs in case of emergency
    function setBaseURI(string memory URI) public onlyRole(Manager) {
        baseURI = URI;
    }

    // Mint X number of Martians for team members
    function mintForTeam(uint256 numberOfTokens) public payable {
        uint256 supply = totalSupply();
        // Ensure presale conditions are met before proceeding
        require(numberOfTokens > 0, "Need to mint at least 1 NFT");
        require(hasRole(Team, msg.sender), "User is not in Team");
        require(supply + numberOfTokens <= Max_Martians, "Purchase would exceed max supply of Martians");
        require(TeamSupply + numberOfTokens <= Max_Team_Martians, "Purchase would exceed max Team supply of Martians");
        uint256 ownerMintedCount = balanceOf(msg.sender);
        require(ownerMintedCount + numberOfTokens <= maxTeamPurchase, "Can only mint 3 NFTs for a team member");

        // Mint i tokens where i is specified by function invoker
        for(uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }

        TeamSupply += numberOfTokens;
    }

    // Explicit functions to pause or resume the vip sale of Martians NFT
    function TogglePreSale() external onlyRole(Manager) {
        PreSaleIsActive = !PreSaleIsActive;
    }

    function setPreSalePrice(uint256 _price) external onlyRole(Manager) {
        PreSalePrice = _price;
    }
    // Mint X number of Martians when invoked along with specified ETH - Presale only for VIP users
    function mintMartianPresale(uint256 numberOfTokens) public payable {
        uint256 supply = totalSupply();
        // Ensure presale conditions are met before proceeding
        require(numberOfTokens > 0, "Need to mint at least 1 NFT");
        require(PreSaleIsActive, "Pre Sale must be active to mint Martians");
        require(hasRole(PreSaleList, msg.sender), "User is not in PreSaleList");
        require(supply + numberOfTokens <= Max_Martians, "Purchase would exceed max supply of Martians");
        require(PreMintedSupply + numberOfTokens <= Max_PreSale_Martians, "Purchase would exceed max preSale supply of Martians");
        require(PreSalePrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        uint256 ownerMintedCount = balanceOf(msg.sender);
        require(ownerMintedCount + numberOfTokens <= maxPreSalePurchase, "Can only mint 3 NFTs in PreSale");

        // Mint i tokens where i is specified by function invoker
        for(uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }

        PreMintedSupply += numberOfTokens;
    }

    // Explicit functions to pause or resume the sale of Martians NFT
    function ToggleSale() external onlyRole(Manager) {
        SaleIsActive = !SaleIsActive;
    }
    function setSalePrice(uint256 _price) external onlyRole(Manager) {
        SalePrice = _price;
    }
    // Standart mint for buyers
    function mintMartian(uint256 numberOfTokens) public payable {
        uint256 supply = totalSupply();
        // Ensure conditions are met before proceeding
        require(numberOfTokens > 0, "Need to mint at least 1 NFT");
        require(SaleIsActive, "Sale must be active to mint Martians");
        require(supply + numberOfTokens <= Max_Martians, "Purchase would exceed max supply of Martians");
        require(SalePrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");

        // Mint i tokens
        for(uint32 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function giveAway(address _to, uint256 numberOfTokens) external onlyRole(Manager) {
        uint256 supply = totalSupply();
        // Ensure conditions are met before proceeding
        require(numberOfTokens > 0, "Need to mint at least 1 NFT");
        require(supply + numberOfTokens <= Max_Martians, "Purchase would exceed max supply of Martians");

        for (uint32 i; i < numberOfTokens; i++) {
            _safeMint(_to, supply + i);
        }
    }

    // Override the below functions from parent contracts

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}