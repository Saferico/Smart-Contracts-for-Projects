// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 < 0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TruorDie is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private supply;

    // URIs
    string public uriPrefix = "ipfs://Qmb8vp2qhQvZY8Sb5kqpiC9WLcawr7Fcykzv3hCV2v7Vd9/";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;
    
    // Costs
    uint256 public presaleCost = 0.1 ether;
    uint256 public publicsaleCost = 0.15 ether;

    // Supplies
    uint256 public maxSupply = 10000;
    uint256 public maxSupplyLimit = 10000;

    // Per Address & TX Limits
    uint256 public nftPresalePerAddressLimit = 100;
    uint256 public nftPublicsalePerAddressLimit = 100;
    uint256 public maxMintAmountPerTx = 5;

    // Stats
    bool public paused = false;
    bool public presale = true;
    bool public onlyWhitelisted = true;
    bool public revealed = false;

    // Whitelist Addresses
    mapping(address => bool) public whitelistedAddressesList;

    // Minted Balances
    mapping(address => uint256) public addressPresaleMintedBalance;
    mapping(address => uint256) public addressPublicsaleMintedBalance;

    // Constructor
    constructor() ERC721("Tru or Die", "TD") {
        setHiddenMetadataUri("ipfs://Qmbn7yWfYt81sqom1onSoiiNfkw44AsJAnpC8GMbF5kNa2/");
    }

    // Mint Compliance
    modifier mintCompliance(uint256 _mintAmount) {
        if(presale == true) {
            if(onlyWhitelisted == true) {
                require(isInWhiteList(msg.sender), "MSG: User is not whitelisted");
            }

            uint256 ownerMintedCount = addressPresaleMintedBalance[msg.sender];
            require(ownerMintedCount + _mintAmount <= nftPresalePerAddressLimit, "MSG: Max NFT per address exceeded for presale");
        } else {
            uint256 ownerMintedCount = addressPublicsaleMintedBalance[msg.sender];
            require(ownerMintedCount + _mintAmount <= nftPublicsalePerAddressLimit, "MSG: Max NFT per address exceeded for publicsale");
        }

        require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, "MSG: Invalid mint amount");
        require(supply.current() + _mintAmount <= maxSupplyLimit, "MSG: Max supply exceeded");
        _;
    }

    // Total Supply
    function totalSupply() public view returns (uint256) {
        return supply.current();
    }

    // Mint
    function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) {
        require(!paused, "MSG: The contract is paused");
        
        if(presale == true) {
            require(msg.value >= presaleCost * _mintAmount, "MSG: Insufficient funds");
        } else {
            require(msg.value >= publicsaleCost * _mintAmount, "MSG: Insufficient funds");
        }

        _mintLoop(msg.sender, _mintAmount);

        withdraw();
    }

    // Mint Functions
    function ownerMint(uint256 _mintAmount) public onlyOwner {
        require(!paused, "MSG: The contract is paused");

        _mintLoop(msg.sender, _mintAmount);
    }

    function ownerMintSpecific(uint256 _tokenId) public onlyOwner {
        require(!paused, "MSG: The contract is paused");

        _safeMint(msg.sender, _tokenId);

        if(presale == true) {
            addressPublicsaleMintedBalance[msg.sender]++;
        } else {
            addressPublicsaleMintedBalance[msg.sender]++;
        }
    }
  
    function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
        _mintLoop(_receiver, _mintAmount);
    }

    // Wallet Of Owner
    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);

        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;
                ownedTokenIndex++;
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    // Token URI
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "MSG: URI query for nonexistent token");

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();

        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix)) : "";
    }

    // Presale Cost
    function setPresaleCost(uint256 _cost) public onlyOwner {
        presaleCost = _cost;
    }

    // Publicsale Cost
    function setPublicsaleCost(uint256 _cost) public onlyOwner {
        publicsaleCost = _cost;
    }

    // Set NFT Publicsale Per Address Limit
    function setNFTPublicsalePerAddressLimit(uint256 _cost) public onlyOwner {
        nftPublicsalePerAddressLimit = _cost;
    }

    // Set NFT Presale Per Address Limit
    function setNFTPresalePerAddressLimit(uint256 _cost) public onlyOwner {
        nftPresalePerAddressLimit = _cost;
    }

    // Set URI Prefix
    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    // Set URI Suffix
    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    // Set Hidden Metadata URI
    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    // Set Paused
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    // Set Presale
    function setPresale(bool _state) public onlyOwner {
        presale = _state;
    }

    // Set Revealed
    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    // Withdraw
    function withdraw() public payable {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // Mint Loop
    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            supply.increment();

            _safeMint(_receiver, supply.current());

            if(presale == true) {
                addressPresaleMintedBalance[msg.sender]++;
            } else {
                addressPublicsaleMintedBalance[msg.sender]++;
            }
        }
    }

    // Base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    // Set Only Whitelisted
    function setOnlyWhitelisted(bool _state) public onlyOwner {
        onlyWhitelisted = _state;
    }
    
    // Whitelist Functions
    function addToWhiteList(address _addr) public onlyOwner {
        whitelistedAddressesList[_addr] = true;
    }

    function addArrayToWhiteList(address[] memory _addrs) public onlyOwner {
        for (uint256 i = 0;i< _addrs.length; i++) {
            whitelistedAddressesList[_addrs[i]] = true; 
        }
    }

    function removeFromWhiteList(address _addr) public onlyOwner {
        whitelistedAddressesList[_addr] = false;
    }

    function isInWhiteList(address _addr) public view returns (bool) {
        return whitelistedAddressesList[_addr]  || _addr == owner();
    }
}