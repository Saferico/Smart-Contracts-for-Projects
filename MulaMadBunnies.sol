// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract MulaMadBunnies is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string public hiddenMetadataUri;
    string public baseURI;
    string public baseExtension = ".json";
    bool public paused = false;
    bool public revealed;
    bytes32 public merkleRoot;
    uint256 public maxSupply = 7777;
    uint256 public maxMint = 2;
    uint256 public cost = 0 ether;

    constructor(string memory _hiddenMetadataUri) ERC721A("Mula Mad Bunnies", "MMB") {
        setHiddenMetadataUri(_hiddenMetadataUri);
        _safeMint(msg.sender, 3);
    }
    
    // Whitelist mint
    function whitelistMint(uint256 quantity, bytes32[] calldata _merkleProof)
        public
        payable
        nonReentrant
    {
        require(!paused, "The whitelist sale is not enabled!"); 
        uint256 supply = totalSupply();
        require(quantity > 0, "Quantity Must Be Higher Than Zero");
        require(supply + quantity <= maxSupply, "Max Supply Reached");
        require(
            balanceOf(msg.sender) + quantity <= maxMint,
            "You're not allowed to mint this Much!"
        );
        require(msg.value >= cost * quantity, "Not enough ether!");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProof.verify(_merkleProof, merkleRoot, leaf),
            "Invalid proof!"
        );

        _safeMint(msg.sender, quantity);
    }

    // Owner mint
    function devMint(uint256 quantity) external onlyOwner {
        uint256 supply = totalSupply();
        require(quantity > 0, "Quantity must be higher than zero!");
        require(supply + quantity <= maxSupply, "Max supply reached!");
        _safeMint(msg.sender, quantity);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!revealed) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();

        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    // 

    // Set supply of nfts
    function setMaxSupply(uint256 _amount) public onlyOwner {
        maxSupply = _amount;
    }

    // Set merkleRoot for whitelist
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // Control sale state
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    // Set max per wallet both presale and public sale
    function setMax(uint256 _amount) public onlyOwner {
        maxMint = _amount;
    }

    // Set mint price for both presale and public sale
    function setPrice(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    // Set hidden metadata URI
    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    // for reveal your collection
    function setReveal(bool _state) public onlyOwner {
        revealed = _state;
    }

    // Set baseURI
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // Airdrop NFT to anyone
    function airdrop(address _address ,uint256 quantity) public onlyOwner {
        uint256 supply = totalSupply();
        require(quantity > 0, "Quantity must be higher than zero!");
        require(supply + quantity <= maxSupply, "Max supply reached!");
        _safeMint(_address, quantity);
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    // Withdraw the funds from the contract
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}