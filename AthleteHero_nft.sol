// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface InterfaceAthleteHero {
    function getOwnerOf(uint256 tokenId) external view returns (address owner);
	function getTokenIds(address _owner) external view returns (uint[] memory);
}

/// @custom:security-contact security@athletehero.com
contract AthleteHeroTeam is ERC721, ERC721Enumerable, Pausable, Ownable, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    string baseURI;
	uint256 public cost = 0.285 ether;
	uint256 public costWhitelist = 0.285 ether;
	uint256 public maxSupply = 100;
	uint256 public maxMintAmount = 100;
	bool public pauseGeneralMint = false;
	bool public pauseWhitelistMint = false;
	mapping(address => uint8) private whitelist;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
	) ERC721(_name,_symbol) {
        _setBaseURI(_initBaseURI);
        _tokenIdCounter.increment();
	}

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
	
    function _setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
	
    function _pauseGeneralMint(bool _pauseValue) public onlyOwner {
        pauseGeneralMint = _pauseValue;
    }
	
    function _pauseWhitelistMint(bool _pauseValue) public onlyOwner {
        pauseWhitelistMint = _pauseValue;
    }
	
    function setSupply(uint256 _newMaxSupply,uint256 _newMaxAmount) public onlyOwner {
        maxSupply = _newMaxSupply;
        maxMintAmount = _newMaxAmount;
    }
	
    function setCost(uint256 _cost,uint256 _costWhitelist) public onlyOwner {
        cost = _cost;
        costWhitelist = _costWhitelist;
    }
	
    function addWhiteList(address[] calldata addresses,uint[] calldata mintAmounts) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
                whitelist[addresses[i]] =  uint8(mintAmounts[i]);
        }
    }

    function ownerMint(address to) public onlyOwner nonReentrant {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }
	
    function mint(uint256 _mintAmount) public payable nonReentrant whenNotPaused {
       uint256 supply = totalSupply();
       require(!pauseGeneralMint,"Minting is not avaliable!");
       require(_mintAmount > 0,"Mint amount must be more than zero!");
       require(_mintAmount <= maxMintAmount,string(abi.encodePacked("You are not allowed to mint more than ",Strings.toString(maxMintAmount),".")));
       require(supply + _mintAmount <= maxSupply,"Purchase would exceed max supply of NFTs.");
       if (msg.sender != owner()) {
              require(msg.value >= cost * _mintAmount,"You did not send enough ether.");
       }
       for (uint256 i = 1; i <= _mintAmount; i++) {
              _safeMint(msg.sender, supply + i);
       }
    }
	
    function mintWhitelist(uint256 _mintAmount) public payable nonReentrant whenNotPaused {
       uint256 supply = totalSupply();
       require(!pauseWhitelistMint,"Minting is not avaliable!");
       require(_mintAmount > 0,"Mint amount must be more than zero!");
	   require(_mintAmount <= whitelist[msg.sender],"You are not allowed to mint, or you are trying to mint more than you are allowed.");
       require(_mintAmount <= maxMintAmount,string(abi.encodePacked("You are not allowed to mint more than ",Strings.toString(maxMintAmount),".")));
       require(supply + _mintAmount <= maxSupply,"Purchase would exceed max supply of NFTs.");
       if (msg.sender != owner()) {
              require(msg.value >= costWhitelist * _mintAmount,"You did not send enough ether.");
       }
       for (uint256 i = 1; i <= _mintAmount; i++) {
              _safeMint(msg.sender, supply + i);
       }
	   whitelist[msg.sender] = uint8(whitelist[msg.sender]) - uint8(_mintAmount);
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) 
    {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

		string memory _tokenId = Strings.toString(tokenId);

        if (bytes(baseURI).length == 0) {
            return _tokenId;
        }
		
        if (bytes(_tokenId).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenId, ".json"));
        }

        return super.tokenURI(tokenId);
    }
	
	function getOwnerOf(uint256 tokenId) external view returns (address owner) {
        return (ownerOf(tokenId));
    }
	
	function getTokenIds(address _owner) external view returns (uint[] memory) {
        uint[] memory _tokensOfOwner = new uint[](ERC721.balanceOf(_owner));
        uint i;

        for (i=0;i<ERC721.balanceOf(_owner);i++){
            _tokensOfOwner[i] = ERC721Enumerable.tokenOfOwnerByIndex(_owner, i);
        }
        return (_tokensOfOwner);
    }    

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}