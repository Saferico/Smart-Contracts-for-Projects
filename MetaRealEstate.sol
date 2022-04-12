// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MetaRealEstate is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
	string baseURI;
	string prerevealURI;
	string public baseExtension = ".json";
	uint256 public MAX_TOKENS=5000;
	uint256 public MAX_TOKENS_PRESALE=5000;
	uint256 public FEE;
	uint256 public FEEpresales;
	uint256 public MAXNFTperTX;
	uint256 public MAXNFTperADDR;
	uint256 public _tokenidreserved;
	
	bool public reveal;

	bool public paused = false;
	bool public presale = false;
	bool public publicsale = false;
	mapping(address => bool) public whitelisted;
	//mapping(address => uint256) NFTperAddress;
	//address ReservedAddress = 0xc4365492792f63aF72a5465d74A500f174e4AEa0;
	
	
	

    constructor(string memory mybaseuri, string memory myrevealuri) ERC721("Meta Real Estate", "MRE") {
		_tokenIdCounter.increment();
		setBaseURI(mybaseuri);
		setprerevealURI(myrevealuri);
		FEE=20000000000000000;
		FEEpresales=20000000000000000;
		MAXNFTperTX = 10;
		reveal=false;
		MAXNFTperADDR = 5;
		_tokenidreserved = 11001;
	}
	
	// Admin functions
	
	function whitelistUser(address _user) public onlyOwner {
		whitelisted[_user] = true;
	
    }
	function whitelistUserBulk(address[] memory _users) public onlyOwner {
        uint i;
		for(i=0;i<_users.length;i++){
			whitelisted[_users[i]] = true;
			}
	}
	
	function setCost(uint256 _newCost) public onlyOwner {
		FEE = _newCost;
	}

	function setMaxTokens(uint256 _newMax) public onlyOwner {
		MAX_TOKENS = _newMax;
	}
	
	/*function settokenidreserved(uint256 _newtokenidreserved) public onlyOwner {
		require(_newtokenidreserved>11000,"value must be above 11500");
		require(_newtokenidreserved<11112,"value must be below 12000");
		_tokenidreserved = _newtokenidreserved;
	}*/
	
	function setReveal(bool _newreveal) public onlyOwner {
		reveal = _newreveal;
	}
	
	function setMaxTokensPresale(uint256 _newMax) public onlyOwner {
		MAX_TOKENS_PRESALE = _newMax;
	}
	
	function setPresaleCost(uint256 _newCost) public onlyOwner {
		FEEpresales = _newCost;
	}
 
	function removeWhitelistUser(address _user) public onlyOwner {
		whitelisted[_user] = false;
	}
	
	function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
	
	
	function _baseURI() internal view virtual override returns (string memory) {
		return baseURI;
	}
  
	function setBaseURI(string memory _newBaseURI) public onlyOwner {
		baseURI = _newBaseURI;
	}

	function setprerevealURI(string memory _newrevealURI) public onlyOwner {
		prerevealURI = _newrevealURI;
	}	

	function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
		baseExtension = _newBaseExtension;
	}
	
	function pause(bool _state) public onlyOwner {
		paused = _state;
	}
	
	function startpresale(bool _state) public onlyOwner {
		presale = _state;
	}

	function startpublicsale(bool _state) public onlyOwner {
		publicsale = _state;
	}
	
	function setMaxNFTperBuyer(uint256 newMax) public onlyOwner {
		MAXNFTperADDR = newMax;
	}
	
	function setMaxNFTperTX(uint256 newMax) public onlyOwner {
		MAXNFTperTX = newMax;
	}

	function withdraw() public payable onlyOwner {
		(bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
		require(success,"Transfer failed.");
	}
	
	function increaseCounter() public onlyOwner {
		_tokenIdCounter.increment();
	}
	
	function decreaseCounter() public onlyOwner {
		_tokenIdCounter.decrement();
	}

    //Mint Functions
	function safeMint(uint minttimes) public payable {
		
		require(!paused);
		
		
			if(msg.sender==owner()){
				require(MAX_TOKENS >= _tokenIdCounter.current() + minttimes - 1, "Not enough tokens left to buy.");
				for(uint i=0;i<minttimes;i++){
					_safeMint(msg.sender, _tokenIdCounter.current());	
					_tokenIdCounter.increment();
					
				}
			}
			
			else if (presale==true){
                require(MAX_TOKENS_PRESALE >= _tokenIdCounter.current() + minttimes - 1, "Not enough tokens left to buy.");
				require(msg.value >= FEEpresales * minttimes, "Amount of ether sent not correct.");
				require(minttimes<=MAXNFTperTX,"Max 5 NFTs per transaction!");
				require(balanceOf(msg.sender)+minttimes<=MAXNFTperADDR,"Max 10 NFTs per wallet!");
				require(whitelisted[msg.sender],"Youre not whitelisted!!");
				for(uint i=0;i<minttimes;i++){
					_safeMint(msg.sender, _tokenIdCounter.current());	
					_tokenIdCounter.increment();
					
				}
			}
			
			else if (publicsale==true){
                require(MAX_TOKENS >= _tokenIdCounter.current() + minttimes - 1, "Not enough tokens left to buy.");
				require(msg.value >= FEE * minttimes, "Amount of ether sent not correct.");
				require(minttimes<=MAXNFTperTX,"Max 5 NFTs per transaction!");
				require(balanceOf(msg.sender)+minttimes<=MAXNFTperADDR,"Max 10 NFTs per wallet!");
				for(uint i=0;i<minttimes;i++){
					_safeMint(msg.sender, _tokenIdCounter.current());	
					_tokenIdCounter.increment();
					
				}
			}

            else{
                require(publicsale,"Public sale not yet started!");
            }
			
		
	}
	
	//Airdrop function
	function safeMintAirdrop(uint minttimes, address toAddress) public payable onlyOwner {
		
		require(!paused);
		
		require(minttimes <= MAXNFTperTX,"Max 10 NFTs per tx!");
		
			
				
				for(uint i=0;i<minttimes;i++){
					_safeMint(toAddress, _tokenIdCounter.current());	
					_tokenIdCounter.increment();
					
				}
			
			
					
		
	}
	
	/*function safeMintReserved(uint minttimes) public payable {
		
		require(!paused);
		
		require(minttimes <= MAXNFTperTX,"Max 10 NFTs per tx!");
		require(_tokenidreserved + minttimes < 11112,"Cannot go above NFT 11111");
		
			
				
				for(uint i=0;i<minttimes;i++){
					_safeMint(ReservedAddress, _tokenidreserved);	
					_tokenidreserved++;
					
				}
			
			
					
		
	}*/

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override(ERC721, ERC721URIStorage)
    returns (string memory)
	{
		require(
		_exists(tokenId),
		"ERC721Metadata: URI query for nonexistent token"
		);
		if (reveal){
		string memory currentBaseURI = _baseURI();
		return bytes(currentBaseURI).length > 0
			? string(abi.encodePacked(currentBaseURI, uint2str(tokenId), baseExtension))
			: "";}
		else{
				return prerevealURI;
		}
	}
	
	//Return current counter value
	function getCounter()
        public
        view
        returns (uint256)
    {
        return _tokenIdCounter.current();
    }
	
	
	

	
	
}