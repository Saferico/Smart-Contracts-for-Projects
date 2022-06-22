//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/*
MandalaFON.sol

Written by: loming.loopring.eth
*/

contract MandalaFON is Ownable, ERC721A {
    // Note: This should be marked constant if you NEVER plan on changing them to save gas.
        // That said, leaving the option open in case you wanted to increase mints/decrease collection size.
    // Note AGAIN: That said, setting this to a constant saves the SLOADs and about 1.8% gas per mint.
    uint256 constant public MAX_SUPPLY = 1011;
    
    // Note: For even MORE gas efficiency you can actually pack bools into one bit instead of 8.
        // That said, it's unnecessary complexity at a time like this, but a fun experiment for the reader!
    // Updated: I've set paused to be true to start, so that the team has time to make annoucements etc.
        // (See publicSale/publicWhitelisted logic for more information)
    bool public paused = false;
    bool public revealed = false;  

    string public baseURI = "ipfs://QmVtenH9DyMGTHwgguVBvrsD77Z3X7eqPWm5KVNdaVi63L/";

    // Updated: Setting the default value here instead of the constructor.
    // I'd personally make this a constant since it shouldn't have to change, but leaving for v1 compatability.
    string public hiddenMetadataUri = "ipfs://QmYT1CN1LwzVC1znsUYmeZqCFHzAwgEq12WbJXVc6nK7VQ/";
    
    string constant public uriSuffix = ".json";

    // Updated: This is a new string that the owners can use for CONTRACT_URI
    // This is how you can easily set Collection name/description/image,
    // as well as royalty fees and wallet address.
    string public CONTRACT_URI = "ipfs://QmRxwszxu169bnxxaHbSPw55L5LinWPUYEgSgfg24T7CgA";

    // Updated AGAIN: By disabling this and ONLY tracking one mapping we save about 11.8% gas per WL mint.
    //mapping(address => uint256) public publicWhitelistAddressMintedBalance;

        // That said, it's the quickest and easiest way to handle the previous v1 logic
    
    // Note: If you wanted to save even MORE gas, you could disable this mapping entirely and only use balanceOf(msg.sender)
    // This saves you about 19.5% per publicMint at the cost of not letting users buy on secondary and THEN mint
    // Basically you save out on one SLOAD and SSTORE PER MINT!
    // mapping(address => uint256) public numUserMints;

    // Updated: I removed the initial hidden metadata URI from here as it was not necessary
        // Also, the constructor no longer sets the Merkle Root to separate out those functions
        // This does require a second call to the contract, but prevents a failure in that call from preventing deployment.
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721A(name_, symbol_) { }

    /*
     *

    $$$$$$$\            $$\                      $$\                     $$$$$$$$\                              $$\     $$\                               
    $$  __$$\           \__|                     $$ |                    $$  _____|                             $$ |    \__|                              
    $$ |  $$ | $$$$$$\  $$\ $$\    $$\ $$$$$$\ $$$$$$\    $$$$$$\        $$ |   $$\   $$\ $$$$$$$\   $$$$$$$\ $$$$$$\   $$\  $$$$$$\  $$$$$$$\   $$$$$$$\ 
    $$$$$$$  |$$  __$$\ $$ |\$$\  $$  |\____$$\\_$$  _|  $$  __$$\       $$$$$\ $$ |  $$ |$$  __$$\ $$  _____|\_$$  _|  $$ |$$  __$$\ $$  __$$\ $$  _____|
    $$  ____/ $$ |  \__|$$ | \$$\$$  / $$$$$$$ | $$ |    $$$$$$$$ |      $$  __|$$ |  $$ |$$ |  $$ |$$ /        $$ |    $$ |$$ /  $$ |$$ |  $$ |\$$$$$$\  
    $$ |      $$ |      $$ |  \$$$  / $$  __$$ | $$ |$$\ $$   ____|      $$ |   $$ |  $$ |$$ |  $$ |$$ |        $$ |$$\ $$ |$$ |  $$ |$$ |  $$ | \____$$\ 
    $$ |      $$ |      $$ |   \$  /  \$$$$$$$ | \$$$$  |\$$$$$$$\       $$ |   \$$$$$$  |$$ |  $$ |\$$$$$$$\   \$$$$  |$$ |\$$$$$$  |$$ |  $$ |$$$$$$$  |
    \__|      \__|      \__|    \_/    \_______|  \____/  \_______|      \__|    \______/ \__|  \__| \_______|   \____/ \__| \______/ \__|  \__|\_______/ 
                                                                                                                                                      
    *
    */

    // This function is if you want to override the first Token ID# for ERC721A
       // In this case, HR is starting at #1 instead of #0
    // Note: Fun fact - by overloading this method you save a small amount of gas for minting (technically just the first mint)
    //function _startTokenId() internal view virtual override returns (uint256) {
    //    return 1;
    //}


    /*
     *

    $$$$$$$\            $$\       $$\ $$\                 $$$$$$$$\                              $$\     $$\                               
    $$  __$$\           $$ |      $$ |\__|                $$  _____|                             $$ |    \__|                              
    $$ |  $$ |$$\   $$\ $$$$$$$\  $$ |$$\  $$$$$$$\       $$ |   $$\   $$\ $$$$$$$\   $$$$$$$\ $$$$$$\   $$\  $$$$$$\  $$$$$$$\   $$$$$$$\ 
    $$$$$$$  |$$ |  $$ |$$  __$$\ $$ |$$ |$$  _____|      $$$$$\ $$ |  $$ |$$  __$$\ $$  _____|\_$$  _|  $$ |$$  __$$\ $$  __$$\ $$  _____|
    $$  ____/ $$ |  $$ |$$ |  $$ |$$ |$$ |$$ /            $$  __|$$ |  $$ |$$ |  $$ |$$ /        $$ |    $$ |$$ /  $$ |$$ |  $$ |\$$$$$$\  
    $$ |      $$ |  $$ |$$ |  $$ |$$ |$$ |$$ |            $$ |   $$ |  $$ |$$ |  $$ |$$ |        $$ |$$\ $$ |$$ |  $$ |$$ |  $$ | \____$$\ 
    $$ |      \$$$$$$  |$$$$$$$  |$$ |$$ |\$$$$$$$\       $$ |   \$$$$$$  |$$ |  $$ |\$$$$$$$\   \$$$$  |$$ |\$$$$$$  |$$ |  $$ |$$$$$$$  |
    \__|       \______/ \_______/ \__|\__| \_______|      \__|    \______/ \__|  \__| \_______|   \____/ \__| \______/ \__|  \__|\_______/ 

    *
    */


    /*
     *

    $$\    $$\ $$\                               $$$$$$$$\                              $$\     $$\                               
    $$ |   $$ |\__|                              $$  _____|                             $$ |    \__|                              
    $$ |   $$ |$$\  $$$$$$\  $$\  $$\  $$\       $$ |   $$\   $$\ $$$$$$$\   $$$$$$$\ $$$$$$\   $$\  $$$$$$\  $$$$$$$\   $$$$$$$\ 
    \$$\  $$  |$$ |$$  __$$\ $$ | $$ | $$ |      $$$$$\ $$ |  $$ |$$  __$$\ $$  _____|\_$$  _|  $$ |$$  __$$\ $$  __$$\ $$  _____|
     \$$\$$  / $$ |$$$$$$$$ |$$ | $$ | $$ |      $$  __|$$ |  $$ |$$ |  $$ |$$ /        $$ |    $$ |$$ /  $$ |$$ |  $$ |\$$$$$$\  
      \$$$  /  $$ |$$   ____|$$ | $$ | $$ |      $$ |   $$ |  $$ |$$ |  $$ |$$ |        $$ |$$\ $$ |$$ |  $$ |$$ |  $$ | \____$$\ 
       \$  /   $$ |\$$$$$$$\ \$$$$$\$$$$  |      $$ |   \$$$$$$  |$$ |  $$ |\$$$$$$$\   \$$$$  |$$ |\$$$$$$  |$$ |  $$ |$$$$$$$  |
        \_/    \__| \_______| \_____\____/       \__|    \______/ \__|  \__| \_______|   \____/ \__| \______/ \__|  \__|\_______/ 

    *
    */

    // Note: walletOfOwner is only really necessary for enumerability when staking/using on websites etc.
        // That said, it's again a public view so we can keep it in.
        // This could also be optimized if someone REALLY wanted, but it's just a public view.
        // Check the pinned tweets of 0xInuarashi for more ideas on this method!
        // For now, this is just the version that existed in v1.
    function walletOfOwner(address _owner) public view returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = 1;
        uint256 ownedTokenIndex = 0;

        while (ownedTokenIndex < ownerTokenCount && currentTokenId <= MAX_SUPPLY) {
            address currentTokenOwner = ownerOf(currentTokenId);

            if (currentTokenOwner == _owner) {
                ownedTokenIds[ownedTokenIndex] = currentTokenId;

                ownedTokenIndex++;
            }

        currentTokenId++;
        }

        return ownedTokenIds;
    }

    // Updated: There was no reason this needed to be virtual unless something plans on inheriting HR.
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        // Note: You don't REALLY need this require statement since nothing should be querying for non-existing tokens after reveal.
            // That said, it's a public view method so gas efficiency shouldn't come into play.
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        
        // Updated: The old contract had unnecessary logic and conditionals about a _baseURI that was set by default.
        if (revealed) {
            return string(abi.encodePacked(baseURI, Strings.toString(_tokenId), uriSuffix));
        }
        else {
            return string(abi.encodePacked(hiddenMetadataUri, Strings.toString(_tokenId), uriSuffix));
        }
    }

    // https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return CONTRACT_URI;
    }

    /*
     *

     $$$$$$\                                                    $$$$$$$$\                              $$\     $$\                               
    $$  __$$\                                                   $$  _____|                             $$ |    \__|                              
    $$ /  $$ |$$\  $$\  $$\ $$$$$$$\   $$$$$$\   $$$$$$\        $$ |   $$\   $$\ $$$$$$$\   $$$$$$$\ $$$$$$\   $$\  $$$$$$\  $$$$$$$\   $$$$$$$\ 
    $$ |  $$ |$$ | $$ | $$ |$$  __$$\ $$  __$$\ $$  __$$\       $$$$$\ $$ |  $$ |$$  __$$\ $$  _____|\_$$  _|  $$ |$$  __$$\ $$  __$$\ $$  _____|
    $$ |  $$ |$$ | $$ | $$ |$$ |  $$ |$$$$$$$$ |$$ |  \__|      $$  __|$$ |  $$ |$$ |  $$ |$$ /        $$ |    $$ |$$ /  $$ |$$ |  $$ |\$$$$$$\  
    $$ |  $$ |$$ | $$ | $$ |$$ |  $$ |$$   ____|$$ |            $$ |   $$ |  $$ |$$ |  $$ |$$ |        $$ |$$\ $$ |$$ |  $$ |$$ |  $$ | \____$$\ 
     $$$$$$  |\$$$$$\$$$$  |$$ |  $$ |\$$$$$$$\ $$ |            $$ |   \$$$$$$  |$$ |  $$ |\$$$$$$$\   \$$$$  |$$ |\$$$$$$  |$$ |  $$ |$$$$$$$  |
     \______/  \_____\____/ \__|  \__| \_______|\__|            \__|    \______/ \__|  \__| \_______|   \____/ \__| \______/ \__|  \__|\_______/ 

     *
     */

    function setBaseURI(string memory _baseUri) public onlyOwner {
        baseURI = _baseUri;
    }

    // Note: I don't see this needing to change, especially at this point.
        // But, again, leaving for posterity/compatability.
    function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function reveal() public onlyOwner {
      revealed = true;
    }

    // https://docs.opensea.io/docs/contract-level-metadata
    function setContractURI(string memory _contractURI) public onlyOwner {
        CONTRACT_URI = _contractURI;
    }

    // Note: Another option is to inherit Pausable without implementing the logic yourself.
        // This is fine for now and I'm keeping it for compatability with v1
        // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/Pausable.sol
    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function withdraw() external payable onlyOwner {
        // Get the current funds to calculate community percentage
        // uint256 currBalance = address(this).balance;

        // Withdraw the ENTIRE remaining balance to the team wallet.
        (bool succ, ) =  payable(owner()).call{value: address(this).balance}("");
        require(succ, "Balance transfer failed");
    }

    // Updated: Added owner-only mint functionality to "Airdrop" the old NFTs to the original owners
        // There are cooler and more efficient ways 
    function mint(uint256 quantity) public onlyOwner mintCompliance(quantity) {
        _safeMint(owner(), quantity);
    }

    /*
     *

    $$\      $$\                 $$\ $$\  $$$$$$\  $$\                               
    $$$\    $$$ |                $$ |\__|$$  __$$\ \__|                              
    $$$$\  $$$$ | $$$$$$\   $$$$$$$ |$$\ $$ /  \__|$$\  $$$$$$\   $$$$$$\   $$$$$$$\ 
    $$\$$\$$ $$ |$$  __$$\ $$  __$$ |$$ |$$$$\     $$ |$$  __$$\ $$  __$$\ $$  _____|
    $$ \$$$  $$ |$$ /  $$ |$$ /  $$ |$$ |$$  _|    $$ |$$$$$$$$ |$$ |  \__|\$$$$$$\  
    $$ |\$  /$$ |$$ |  $$ |$$ |  $$ |$$ |$$ |      $$ |$$   ____|$$ |       \____$$\ 
    $$ | \_/ $$ |\$$$$$$  |\$$$$$$$ |$$ |$$ |      $$ |\$$$$$$$\ $$ |      $$$$$$$  |
    \__|     \__| \______/  \_______|\__|\__|      \__| \_______|\__|      \_______/ 

    *
    */

    // Note: Something this simple doesn't HAVE to be a modifier, but it saves a little duplication
    // Updated: Removed the unnecessary isValidateEvent logic
    // Updated: Removed other unnecessary require statements
    modifier mintCompliance(uint256 quantity) {
        require(!paused, "Contract is paused");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough mints left");
        // Note: This wasn't in the original contract, and adding it only costs like 21 gas/mint
        require(tx.origin == msg.sender, "No contract minting");
        _;
    }
}