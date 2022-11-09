// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

contract WAGMICHADS is ERC721AUpgradeable, OwnableUpgradeable{
    using Strings for uint256;

    // Supply
    uint256 public MaxSupply = 20;

    // WL
    address[] public whitelistedAddresses;

    // MaxMint
    uint256 public MaxWLMint = 1;
    mapping(address => uint256) public totalWLMint;

    uint256 public MaxMint = 1;
    mapping(address => uint256) public totalMint;

    // Prices
    uint256 public WLPrice = 214 ether;
    uint256 public PublicPrice = 231 ether;
    
    // CID
    string private  baseTokenUri;
    string private  placeholderTokenUri;

    // Phases
    bool public PrivateSale;
    bool public PublicSale;
    bool public isRevealed;

    // Royalty
    uint96 public royaltyFeesInBips;
    address public royaltyAddress;

	// /!\ this function should be called by the admin trought the proxy once deployed /!\ it can be executed only once /!\																													   
    function initialize(uint96 _royaltyFeesInBips) initializerERC721A initializer public {
        __ERC721A_init("WAGMI CHADS", "WAGMIICHADS");
        __Ownable_init();
        royaltyFeesInBips = _royaltyFeesInBips;
        royaltyAddress = owner();
        setRoyaltyInfo(msg.sender, _royaltyFeesInBips);
    }

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesInBips) public onlyOwner {
        royaltyAddress = _receiver;
        royaltyFeesInBips = _royaltyFeesInBips;
    }

    function supportsInterface(bytes4 interfaceId)
            public
            view
            override(ERC721AUpgradeable)
            returns (bool)
    {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "Cannot be called by a contract");
        _;
    }

    // Pre-Sale WL Function
    function PrivateMint(uint256 _quantity) external payable callerIsUser{
        require(PrivateSale, "Private sale not yet active.");
        require(isWhitelisted(msg.sender), "User is not whitelisted");
        require((totalSupply() + _quantity) <= MaxSupply, "Beyond max supply");
        require((totalWLMint[msg.sender] + _quantity) <= MaxWLMint, "Beyond max mint");
        require(msg.value >= (WLPrice * _quantity), "Payment is below the price");
    
        totalWLMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }

    // Public Sale Function
    function PublicMint(uint256 _quantity) external payable callerIsUser{
        require(PublicSale, "Public sale not yet active.");
        require((totalSupply() + _quantity) <= MaxSupply, "Beyond Max Supply");
        require((totalMint[msg.sender] + _quantity) <= MaxMint, "Beyond max mint");
        require(msg.value >= (PublicPrice * _quantity), "Payment is below the price");

        totalMint[msg.sender] += _quantity;
        _safeMint(msg.sender, _quantity);
    }
	// save as property of contract
    address public crossmintAddress;

    function Crossmint(address _to, uint256 count) external payable callerIsUser {
        require(PublicPrice == msg.value, "Incorrect value sent");
        require((totalSupply() + count) <= MaxSupply, "Beyond Max Supply");
        require(msg.value == (PublicPrice * count), "Payment error");
        require(
            msg.sender == crossmintAddress,
            "This function is for Crossmint only."
        );
        _safeMint(_to, count);
    }

    // include a setting function so that you can change this later
    function setCrossmintAddress(address _crossmintAddress) public onlyOwner {
        require(_crossmintAddress != address(0),"Zero address detected");
        crossmintAddress = _crossmintAddress;
    }					   
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenUri;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        uint256 trueId = tokenId + 1;

        if(!isRevealed){
            return placeholderTokenUri;
        }
        
        return bytes(baseTokenUri).length > 0 ? string(abi.encodePacked(baseTokenUri, trueId.toString(), ".json")) : "";
    }

    //Team Mint event
    event TeamMintEvent(address indexed _to, uint _quantity);

    // Airdrop Function
    function teamMint(address _to, uint _quantity) external onlyOwner {
    require(totalSupply() + _quantity <= MaxSupply, "Reached max Supply");
     _safeMint(_to, _quantity);
     emit TeamMintEvent(_to, _quantity);
    }

    // Add Whitelits Users
    function whitelistUsers(address[] calldata _users) public onlyOwner {
    delete whitelistedAddresses;
    whitelistedAddresses = _users;
    }
 
    // Verify Whitelist Users
    function isWhitelisted(address _user) public view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _user) {
          return true;
      }
    }
    return false;
  }

    function setTokenUri(string memory _baseTokenUri) external onlyOwner{
        baseTokenUri = _baseTokenUri;
    }
    function setPlaceHolderUri(string memory _placeholderTokenUri) external onlyOwner{
        placeholderTokenUri = _placeholderTokenUri;
    }

    // On/Off Pre-sale
    function togglePrivateSale() external onlyOwner{
        PrivateSale = !PrivateSale;
    }

    // On/Off Public Sale
    function togglePublicSale() external onlyOwner{
        PublicSale = !PublicSale;
    }

    // Royalty 
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public onlyOwner {
      receiver = _receiver;
      feeNumerator = _feeNumerator;
    }

    address public receiver;
    uint256 public feeNumerator;

    // Update Pre-sale Cost
    function setWLPrice(uint256 _newWLPrice) public onlyOwner {
    WLPrice = _newWLPrice;
    }

    // Update Public Sale Cost
    function setPublicPrice(uint256 _newPublicPrice) public onlyOwner {
    PublicPrice = _newPublicPrice;
    }

    // Update WL MaxMint
    function setMaxWLMint(uint256 _newMaxWLMint) public onlyOwner {
    MaxWLMint = _newMaxWLMint;
    }

    // Update MaxMint
    function setMaxMint(uint256 _newMaxMint) public onlyOwner {
    MaxMint = _newMaxMint;
    }

    // Update MaxSupply
    function setMaxsupply(uint256 _newMaxSupply) public onlyOwner {
    MaxSupply = _newMaxSupply;
    }

    // Reveal Function
    function toggleReveal() external onlyOwner{
        isRevealed = !isRevealed;
    }

    function withdraw() external onlyOwner{
        payable(msg.sender).transfer(address(this).balance);
    }
}