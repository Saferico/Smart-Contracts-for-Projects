//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract KittenClubHouse is ERC721A, Ownable, Pausable, ReentrancyGuard {
    event SaleStateChange(uint256 _newState);

    using Strings for uint256;

    bytes32 public whitelistMerkleRoot;

    uint256 public maxTokens = 1200;
    uint256 public presaleTokens = 1000;
    uint256 public maxMintPerWallet = 2;
    uint256 public maxMintPerTx = 2;
    uint256 public reservedTokens = 200;

    uint256 public presalePrice;
    uint256 public price;

    string public KCH_PROVENANCE = "43b5a102ae0dbfe386012b841a06a2da95582adad4ec365c88564be4d7f799d1";
    string private notRevealedJson = "ipfs://QmZGvpAmajTuhRKSTXhKZUBqCDsEpYQQwWwXptWMETszmt/";
    string private baseURI;

    struct MintedPerWallet {
        uint256 presale;
        uint256 publicSale;
    }

    enum SaleState {
        NOT_ACTIVE,
        PRESALE,
        PUBLIC_SALE
    }

    SaleState public saleState = SaleState.NOT_ACTIVE;

    bool public revealed = false;

    mapping(address => MintedPerWallet) public mintedPerWallet;
    mapping(address => uint256) private addressToWithdrawalPercentage;
    address[] private withdrawalAddresses;

    receive() external payable {}

    constructor() ERC721A("KittenClubHouse", "KCH") {}

    function setWithdrawalDistrubution(
        address[] memory _wallets,
        uint256[] memory _percentages
    ) public onlyOwner {
        require(
            _wallets.length == _percentages.length,
            "Wallets and pecentages counts don't match!"
        );

        uint256 totalPercentage;
        for (uint256 i = 0; i < _percentages.length; i++) {
            totalPercentage += _percentages[i];
        }
        require(
            totalPercentage == 100,
            "Percentages provided combined value is not 100"
        );
        for (uint256 i = 0; i < _wallets.length; i++) {
            withdrawalAddresses.push(_wallets[i]);
            addressToWithdrawalPercentage[_wallets[i]] = _percentages[i];
        }
    }

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

    modifier canMint(uint256 _amount) {
        require(
            _amount > 0 && _amount <= maxMintPerTx,
            string(abi.encodePacked("Too many tokens per tx!"))
        );
        require(
            msg.value >= getPrice() * _amount,
            string(abi.encodePacked("Not enough ETH!"))
        );
        _;
    }

    modifier whenSaleNotActive() {
        require(saleState == SaleState.NOT_ACTIVE, "Sale already started!");
        _;
    }

    modifier whenAvailable(uint256 _amount) {
        require(
            maxTokens >= _amount + totalSupply(),
            "Not enough tokens left!"
        );
        if (msg.sender != owner()) {
            require(
                maxTokens - reservedTokens >= _amount + totalSupply(),
                "Remaining tokens are reserved!"
            );
        }
        _;
    }

    function deductFromReserve(uint256 _amount) private {
        if (reservedTokens > 0) {
            if (reservedTokens >= _amount) {
                reservedTokens = reservedTokens - _amount;
            } else {
                reservedTokens = 0;
            }
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function setPresalePrice(uint256 _price) external onlyOwner {
        presalePrice = _price;
    }

    function setPublicSalePrice(uint256 _price) external onlyOwner {
        price = _price;
    }

    function startPresale() external onlyOwner whenSaleNotActive {
        require(presalePrice > 0, "Presale price is not set!");
        saleState = SaleState.PRESALE;
        emit SaleStateChange(uint(SaleState.PRESALE));
    }

    function startPublicSale() external onlyOwner whenSaleNotActive {
        require(price > 0, "Public sale price is not set!");
        saleState = SaleState.PUBLIC_SALE;
        emit SaleStateChange(uint(SaleState.PUBLIC_SALE));
    }

    function endPresale() external onlyOwner {
        require(saleState == SaleState.PRESALE, "Presale is not active!");
        saleState = SaleState.NOT_ACTIVE;
        emit SaleStateChange(uint(SaleState.NOT_ACTIVE));
    }

    function revealTokens() external onlyOwner {
        require(!revealed, "Aleardy revealed!");
        require(bytes(_baseURI()).length > 0, "Base URI not set!");
        revealed = true;
    }

    function setBaseURI(string memory _ipfsCID) external onlyOwner {
        baseURI = string(abi.encodePacked("ipfs://", _ipfsCID, "/"));
    }

    function setPresaleTokenCount(uint256 _tokenCount) external onlyOwner {
        presaleTokens = _tokenCount;
    }

    function setMaxMintPerWallet(uint256 _amount) external onlyOwner {
        maxMintPerWallet = _amount;
    }

    function setMaxMintPerTx(uint256 _amount) external onlyOwner {
        maxMintPerTx = _amount;
    }

    function setReservedTokens(uint256 _amount) external onlyOwner {
        require(
            maxTokens >= totalSupply() + _amount,
            "Not enough tokens left to reserve!"
        );
        reservedTokens = _amount;
    }

    function setWhitelistMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        whitelistMerkleRoot = _merkleRoot;
    }

    function airdropNft(uint256 _amount, address _to) external onlyOwner {
        safeMintNfts(_amount, _to);
    }

    function withdrawBalance() external onlyOwner {
        require(
            withdrawalAddresses.length > 0,
            "Withdrawal addresses not set!"
        );
        uint contractBalance = address(this).balance;
        for (uint256 i = 0; i < withdrawalAddresses.length; i++) {
            uint256 withdrawalPercentage = addressToWithdrawalPercentage[
                withdrawalAddresses[i]
            ];
            (bool success, ) = payable(withdrawalAddresses[i]).call{
                value: contractBalance / 100 * withdrawalPercentage
            }("");
            require(success, "Withdrawal failed!");
        }
    }

    function mintWhitelistNft(uint256 _amount, bytes32[] calldata _merkleProof)
        external
        payable
        whenNotPaused
        nonReentrant
        isValidMerkleProof(_merkleProof, whitelistMerkleRoot)
        canMint(_amount)
    {
        require(saleState == SaleState.PRESALE, "Presale not active!");
        require(presaleTokens - _amount > 0, "End of supply!");
        require(
            _amount + mintedPerWallet[msg.sender].presale <= maxMintPerWallet,
            string(abi.encodePacked("Too many tokens per wallet!"))
        );
        safeMintNfts(_amount, msg.sender);
    }

    function mintNft(uint256 _amount)
        external
        payable
        whenNotPaused
        canMint(_amount)
    {
        require(saleState == SaleState.PUBLIC_SALE, "Public sale not active!");
        require(
            _amount + mintedPerWallet[msg.sender].publicSale <=
                maxMintPerWallet,
            string(abi.encodePacked("Too many tokens per wallet!"))
        );
        safeMintNfts(_amount, msg.sender);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");
        if (revealed) {
            return
                string(
                    abi.encodePacked(_baseURI(), (tokenId + 1).toString(), ".json")
                );
        }
        return notRevealedJson;
    }

    function getPrice() public view returns (uint256) {
        if (saleState == SaleState.PRESALE) {
            return presalePrice;
        } else if (saleState == SaleState.PUBLIC_SALE) {
            return price;
        }
        return 0;
    }

    function safeMintNfts(uint256 _amount, address _to)
        private
        whenAvailable(_amount)
    {
        if (msg.sender == owner()) {
            deductFromReserve(_amount);
        }
        _safeMint(_to, _amount);
        if (msg.sender != owner()) {
            if (saleState == SaleState.PUBLIC_SALE) {
                mintedPerWallet[msg.sender].publicSale += _amount;
            } else if (saleState == SaleState.PRESALE) {
                mintedPerWallet[msg.sender].presale += _amount;
                presaleTokens - _amount;
            }
        }
    }
}