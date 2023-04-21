// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721A} from "erc721a/ERC721A.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {OperatorFilterer} from "closedsea/OperatorFilterer.sol";
import {ERC2981} from "openzeppelin/token/common/ERC2981.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

// Specs:
// - 5555 supply
//      - 100 reserved for team
//      - 5455 available for reservation
// - 2 phases:
//      - Phase 1 (WL)
//          - Both public & wl users can reserve tokens (2 max each wallet).
//          - WL have priority, capped at 5455.
//          - Public can only reserve if there are available spots left
//          - e.g. if 5055 are reserved by WL, only 400 can be reserved by public
//      - Phase 2 (public)
//          - Reservation open to public
//          - Public can only reserve if there are available spots left
// - Owner calls airdrop after reservations phases are finished to distribute tokens
// - Owner calls withdraw to withdraw funds from the contract
// - Owner calls stopMint to stop minting forever

contract Doka is ERC721A, Ownable, ERC2981, OperatorFilterer {
    /* -------------------------------------------------------------------------- */
    /*                                   errors                                   */
    /* -------------------------------------------------------------------------- */
    error ErrInvalidValue();
    error ErrReserveClosed();
    error ErrWLIsClosed();
    error ErrMintZero();
    error ErrExceedsMaxPerWallet();
    error ErrExceedsMaxPerTransaction();
    error ErrExceedsSupply();
    error ErrInvalidSignature();
    error ErrMintDisabled();

    /* -------------------------------------------------------------------------- */
    /*                                   events                                   */
    /* -------------------------------------------------------------------------- */
    event EvReserve(address indexed sender, uint256 amount, uint256 value);

    /* -------------------------------------------------------------------------- */
    /*                                  constants                                 */
    /* -------------------------------------------------------------------------- */
    address constant TEAM_ADDRESS = 0x0000000000000000000000000000000000000123;
    uint256 constant MAX_SUPPLY = 5555;
    uint256 constant RESERVED_SUPPLY = 5455;
    uint256 constant MAX_PER_WALLET = 2;
    uint256 constant MAX_PER_TRANSACTION = 2;

    /* -------------------------------------------------------------------------- */
    /*                                   states                                   */
    /* -------------------------------------------------------------------------- */
    // signer
    address internal $signer;

    // operator filterer
    bool internal $operatorFilteringEnabled;

    // erc721
    string internal $baseURI;
    string internal $unrevealedURI;

    // reservation phase
    enum Phase {
        closed,
        wl,
        pub
    }

    Phase internal $phase;

    // price
    uint256 internal $reservePrice = 0.088 ether;

    // counter
    mapping(address => uint256) internal $reserveCounter;

    struct Counter {
        uint16 total;
        uint16 wl;
        uint16 pub;
    }

    Counter internal $counter;

    // addresses
    address[] internal $wlReserveAddresses;
    address[] internal $publicReserveAddresses;

    // mint
    bool internal $mintEnabled = true;

    /* -------------------------------------------------------------------------- */
    /*                                 constructor                                */
    /* -------------------------------------------------------------------------- */
    constructor(address signer_) ERC721A("Doka", "DOKA") {
        // initial states
        $signer = signer_;

        // init operator filtering
        _registerForOperatorFiltering();
        $operatorFilteringEnabled = true;

        // set initial royalty - 5%
        _setDefaultRoyalty(TEAM_ADDRESS, 500);
    }

    /* -------------------------------------------------------------------------- */
    /*                              operator filterer                             */
    /* -------------------------------------------------------------------------- */
    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721A)
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        payable
        override(ERC721A)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * @dev Both safeTransferFrom functions in ERC721A call this function
     * so we don't need to override them.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        payable
        override(ERC721A)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function _isPriorityOperator(address operator) internal pure override returns (bool) {
        // OpenSea Seaport Conduit:
        // https://etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        // https://goerli.etherscan.io/address/0x1E0049783F008A0085193E00003D00cd54003c71
        return operator == address(0x1E0049783F008A0085193E00003D00cd54003c71);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   erc2981                                  */
    /* -------------------------------------------------------------------------- */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() public onlyOwner {
        _deleteDefaultRoyalty();
    }

    /* -------------------------------------------------------------------------- */
    /*                                   erc165                                   */
    /* -------------------------------------------------------------------------- */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, ERC2981) returns (bool) {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC721: 0x80ac58cd
        // - IERC721Metadata: 0x5b5e139f
        // - IERC2981: 0x2a55205a
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   erc721a                                  */
    /* -------------------------------------------------------------------------- */
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return $baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (bytes($baseURI).length == 0) {
            return $unrevealedURI;
        } else {
            return super.tokenURI(tokenId);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                  external                                  */
    /* -------------------------------------------------------------------------- */
    function reserve(uint256 amount_, bool isWL_, bytes calldata signature_) external payable {
        // input checks
        if (amount_ == 0) revert ErrMintZero();
        if (amount_ > MAX_PER_TRANSACTION) revert ErrExceedsMaxPerTransaction();

        // read states
        uint256 __reservePrice = $reservePrice;
        uint256 __count = $reserveCounter[msg.sender];
        Phase __phase = $phase;
        Counter memory __counter = $counter;
        address __signer = $signer;

        // checks
        if (__phase == Phase.closed) revert ErrReserveClosed(); // phase
        if (__phase == Phase.pub && isWL_) revert ErrWLIsClosed(); // phase
        if (msg.value != amount_ * __reservePrice) revert ErrInvalidValue(); // value
        if (__count >= MAX_PER_WALLET) revert ErrExceedsMaxPerWallet(); // maxPerWallet

        // check signature
        if (isWL_) {
            // check signature
            bytes32 hash = keccak256(abi.encodePacked(msg.sender, amount_, isWL_));
            bytes32 ethHash = ECDSA.toEthSignedMessageHash(hash);
            if (ECDSA.recover(ethHash, signature_) != __signer) revert ErrInvalidSignature();
        }

        // check supply
        // - whitelist phase
        if (__phase == Phase.wl) {
            // whitelist
            if (isWL_) {
                if (__counter.wl + amount_ > RESERVED_SUPPLY) revert ErrExceedsSupply();
            }
            // public
            else {
                if (__counter.total + amount_ > RESERVED_SUPPLY) revert ErrExceedsSupply();
            }
        }
        // - public phase
        else {
            if (__counter.total + amount_ > MAX_SUPPLY) revert ErrExceedsSupply();
        }

        // update
        // - reserveCounter
        $reserveCounter[msg.sender] = __count + amount_;

        // - addresses array
        if (isWL_) $wlReserveAddresses.push(msg.sender);
        else $publicReserveAddresses.push(msg.sender);

        // - counter
        uint16 __amount16 = uint16(amount_);
        __counter.total += __amount16;
        if (isWL_) __counter.wl += __amount16;
        else __counter.pub += __amount16;
        $counter = __counter;

        emit EvReserve(msg.sender, amount_, msg.value);
    }

    /* -------------------------------------------------------------------------- */
    /*                                   owners                                   */
    /* -------------------------------------------------------------------------- */
    function setSigner(address signer_) external onlyOwner {
        $signer = signer_;
    }

    function setOperatorFilteringEnabled(bool value) public onlyOwner {
        $operatorFilteringEnabled = value;
    }

    function setPhase(Phase phase_) external onlyOwner {
        $phase = phase_;
    }

    function setReservePrice(uint256 reservePrice_) external onlyOwner {
        $reservePrice = reservePrice_;
    }

    function setBaseURI(string memory baseURI_) external onlyOwner {
        $baseURI = baseURI_;
    }

    // withdraw
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        address _wallet = TEAM_ADDRESS;
        uint256 _payable = balance;
        payable(_wallet).transfer(_payable);
    }

    // airdrop
    struct Holder {
        address addr;
        uint256 amount;
    }

    function airdrop(Holder[] calldata holders_) external onlyOwner {
        if (!$mintEnabled) {
            revert ErrMintDisabled();
        }

        for (uint256 i = 0; i < holders_.length;) {
            Holder memory __holder = holders_[i];
            _mint(__holder.addr, __holder.amount);
            unchecked {
                ++i;
            }
        }

        if (_totalMinted() > MAX_SUPPLY) {
            revert ErrExceedsSupply();
        }
    }

    // stop
    function stopMint() external onlyOwner {
        $mintEnabled = false;
    }

    /* -------------------------------------------------------------------------- */
    /*                                    views                                   */
    /* -------------------------------------------------------------------------- */
    function signer() external view returns (address) {
        return $signer;
    }

    function operatorFilteringEnabled() external view returns (bool) {
        return $operatorFilteringEnabled;
    }

    function phase() external view returns (Phase) {
        return $phase;
    }

    function reservePrice() external view returns (uint256) {
        return $reservePrice;
    }

    function baseURI() external view returns (string memory) {
        return $baseURI;
    }

    function totalReserveCounter() external view returns (uint256) {
        return $counter.total;
    }

    function wlReserveCounter() external view returns (uint256) {
        return $counter.wl;
    }

    function publicReserveCounter() external view returns (uint256) {
        return $counter.pub;
    }

    function wlReserveAddresses() external view returns (address[] memory) {
        return $wlReserveAddresses;
    }

    function publicReserveAddresses() external view returns (address[] memory) {
        return $publicReserveAddresses;
    }

    function reserveCounter(address addr) external view returns (uint256) {
        return $reserveCounter[addr];
    }

    function mintEnabled() external view returns (bool) {
        return $mintEnabled;
    }
}
