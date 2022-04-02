//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract BMC is ERC721, ERC721Enumerable, Ownable {

	
	uint public constant MAX_TOKENS = 7777;
	uint public constant MAX_TOKENS_VIP = 0;
	
	uint private _currentToken = 0;
	
	uint public CURR_MINT_COST_1 = 0.001 ether;
	uint public CURR_MINT_COST_2 = 0.001 ether;
	
	//---- Round based supplies
	string private CURR_ROUND_NAME = "Presale";
	uint private CURR_ROUND_SUPPLY = 3600;
	uint private CURR_ROUND_TIME = 0;
	uint private maxMintAmount = 2;
	uint private nftPerAddressLimit = 20;
	bytes32 public verificationHash1 = 0x8823bdb34f3cea44b8f49a36bb34623948834fb1612a4abaa8574522dbec0a0e;
	bytes32 public verificationHash2 = 0x8823bdb34f3cea44b8f49a36bb34623948834fb1612a4abaa8574522dbec0a0e;
	
	
	uint private currentVIPs = 0;
	
	bool public hasSaleStarted = true;
	bool public onlyWhitelisted = false;
	
	string public baseURI;
	
	mapping(address => uint) public addressMintedBalance;
	
    uint256 private remaining = MAX_TOKENS;
    mapping(uint256 => uint256) private cache;
	
	constructor() ERC721("The Bookmakers NFT", "BMC") {
		setBaseURI("http://api.bookmakersnft.com/bmc/");
	}

	function totalSupply() public view override returns(uint) {
		return _currentToken;
	}


	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
	
	function walletOfOwner(address _owner) public view returns (uint256[] memory)
	{
		uint256 ownerTokenCount = balanceOf(_owner);
		uint256[] memory tokenIds = new uint256[](ownerTokenCount);
		for (uint256 i; i < ownerTokenCount; i++) {
			tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
		}
		return tokenIds;
	}



  
    function drawIndex() private returns (uint256) {
        uint256 i = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, remaining))) % remaining;

        uint index = cache[i] == 0 ? i : cache[i];
		index = index == 0 ? MAX_TOKENS : index;
		
        cache[i] = cache[remaining - 1] == 0 ? remaining - 1 : cache[remaining - 1];
        remaining = remaining - 1;
		
		return index;
    }


	function getInformations() public view returns (string memory, uint,uint,uint, uint, uint, uint ,bool,bool)
	{		
		return (CURR_ROUND_NAME,CURR_ROUND_SUPPLY,CURR_ROUND_TIME,CURR_MINT_COST_1, CURR_MINT_COST_2,maxMintAmount,nftPerAddressLimit, hasSaleStarted, onlyWhitelisted);
	}
   
	function mintNFT1(uint _mintAmount, bytes32[] memory proof) public payable {
		require(msg.value >= CURR_MINT_COST_1 * _mintAmount, "Insufficient funds");
		require(hasSaleStarted == true, "Sale hasn't started");
		require(_mintAmount > 0, "Need to mint at least 1 NFT");
		require(_mintAmount <= maxMintAmount, "Max mint amount per transaction exceeded");
		require(_mintAmount <= CURR_ROUND_SUPPLY, "We're at max supply!");
		require((_mintAmount  + addressMintedBalance[msg.sender]) <= nftPerAddressLimit, "Max NFT per address exceeded");

        if(onlyWhitelisted == true) {
			bytes32 user = keccak256(abi.encodePacked(msg.sender));
			require(verify(user,proof, verificationHash1), "User is not whitelisted");
        }

		for (uint256 i = 1; i <= _mintAmount; i++) {
			addressMintedBalance[msg.sender]++;
			_currentToken++;
			CURR_ROUND_SUPPLY--;
			uint theToken = drawIndex();
			_safeMint(msg.sender, theToken);
		}
	}
	
	function mintNFT2(uint _mintAmount, bytes32[] memory proof) public payable {
		require(msg.value >= CURR_MINT_COST_1 * _mintAmount, "Insufficient funds");
		require(hasSaleStarted == true, "Sale hasn't started");
		require(_mintAmount > 0, "Need to mint at least 1 NFT");
		require(_mintAmount <= maxMintAmount, "Max mint amount per transaction exceeded");
		require(_mintAmount <= CURR_ROUND_SUPPLY, "We're at max supply!");
		require((_mintAmount  + addressMintedBalance[msg.sender]) <= nftPerAddressLimit, "Max NFT per address exceeded");

        if(onlyWhitelisted == true) {
			bytes32 user = keccak256(abi.encodePacked(msg.sender));
			require(verify(user,proof, verificationHash2), "User is not whitelisted");
        }

		for (uint256 i = 1; i <= _mintAmount; i++) {
			addressMintedBalance[msg.sender]++;
			_currentToken++;
			CURR_ROUND_SUPPLY--;
			uint theToken = drawIndex();
			_safeMint(msg.sender, theToken);
		}
	}
	
	//only owner functions
	
	function setNewRound(uint _supply, uint cost1, uint cost2, string memory name, uint perTransactionLimit, uint perAddressLimit, uint theTime, bool isOnlyWhitelisted, bool saleState) public onlyOwner {
		require(_supply <= (MAX_TOKENS - _currentToken), "Exceeded supply");
		CURR_ROUND_SUPPLY = _supply;
		CURR_MINT_COST_1 = cost1;
		CURR_MINT_COST_2 = cost2;
		CURR_ROUND_NAME = name;
		maxMintAmount = perTransactionLimit;
		nftPerAddressLimit = perAddressLimit;
		CURR_ROUND_TIME = theTime;
		hasSaleStarted = saleState;
		onlyWhitelisted = isOnlyWhitelisted;
	}
	
	function setVerificationHash(bytes32 hash1, bytes32 hash2) external onlyOwner
	{
		verificationHash1 = hash1;
		verificationHash2 = hash2;
	}
	
	function verify(bytes32 user, bytes32[] memory proof, bytes32 hash) internal pure returns (bool)
	{
		bytes32 computedHash = user;

		for (uint256 i = 0; i < proof.length; i++) {
			bytes32 proofElement = proof[i];

			if (computedHash <= proofElement) {
				computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
			} else {
				computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
			}
		}
		return computedHash == hash;
	}
	
	function setOnlyWhitelisted(bool _state) public onlyOwner {
		onlyWhitelisted = _state;
	}

	function setBaseURI(string memory _newBaseURI) public onlyOwner {
		baseURI = _newBaseURI;
	}

	function reserveVIP(uint numTokens, address recipient) public onlyOwner {
		require((currentVIPs + numTokens) <= MAX_TOKENS_VIP, "Exceeded VIP supply");
		uint index;
		for(index = 1; index <= numTokens; index++) {
			_currentToken++;
			currentVIPs = currentVIPs + 1;
			uint theToken = currentVIPs + MAX_TOKENS;
			addressMintedBalance[recipient]++;
			_safeMint(recipient, theToken);
		}
	}

	function Giveaways(uint numTokens, address recipient) public onlyOwner {
		require((_currentToken + numTokens) <= MAX_TOKENS, "Exceeded supply");
		uint index;
		// Reserved for the people who helped build this project
		for(index = 1; index <= numTokens; index++) {
			_currentToken++;
			uint theToken = drawIndex();
			addressMintedBalance[recipient]++;
			_safeMint(recipient, theToken);
		}
	}

	function withdraw(uint amount) public onlyOwner {
		require(payable(msg.sender).send(amount));
	}
	
	
	function setSaleStarted(bool _state) public onlyOwner {
		hasSaleStarted = _state;
	}
}