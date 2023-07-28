pragma solidity 0.8.20;
// SPDX-License-Identifier: MIT

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
//import "./closedsea/OperatorFilterer.sol";
import "https://github.com/Vectorized/closedsea/blob/main/src/OperatorFilterer.sol";

contract Lazynaire is
    ERC721A,
    ERC721AQueryable,
    ERC2981,
    Ownable,
    OperatorFilterer
{
    string private _baseTokenURI;
    string private _preRevealURI;
    bool internal _isRevealed;
    // Whether operator filtering is enabled
    bool public operatorFilteringEnabled;
    bool public isPaused;
    Phases internal _currentPhase;
    uint256 internal _collectionSize;
    uint32 public maxMintPerWallet = 2;
    uint256 public standardMintPrice = 0.03 ether;
    uint256 public OGMintPrice = 0.015 ether;
    mapping(address => uint256) public numberMintedPublicSales;
    mapping(Roles => bytes32) private merkleRoot;
    enum Phases {
        PRE_MINT,
        OG,
        WL,
        PUBLIC
    }

    mapping(Phases => uint32[2]) internal _phaseConfig;

    enum Roles {
        OG_HONOURED,
        OG,
        WL,
        ALLOWLIST,
        PUBLIC
    }

    event SetPhaseConfig(uint _phase, uint32 _startTime, uint32 _endTime);

    event UpdateCollectionSize(
        uint256 oldCollectionSize,
        uint256 collectionSize_
    );

    event SetMerkleRoot(Roles _roles, bytes32 merkleRoot);

    /* ============ Errors ============ */
    error Overflow(uint256 mintable, uint256 maxMintPerWallet);
    error IsPaused();
    error NotValidPhase(uint phase);
    error ExceedsCollectionSize(
        uint256 totalSupply,
        uint256 amount,
        uint256 collectionSize
    );
    error NotEligibleToMint(address user, Roles role, Phases currentPhase);
    error ExeedsUsersMintLimit(address user, uint256 amount, uint256 mintable);
    error InsufficientFunds(address user, uint256 value, uint256 mintPrice);
    error ZeroAddress();

    constructor(
        uint256 collectionSize_,
        address _royaltyReceiver
    ) ERC721A("Lazynaire", "LAZYNAIRE") {
        _collectionSize = collectionSize_;

        // 5% royalties
        _setDefaultRoyalty(_royaltyReceiver, 500);

        // Setup marketplace operator filtering
        _registerForOperatorFiltering();
        operatorFilteringEnabled = true;
    }

    /* ============ Public Functions ============ */
    /**
     * Retrieves user's role, if none, will return PUBLIC role
     * @param user_ user's address to check role
     * @param proof_  merkle proof for user's address
     */
    function getRole(
        address user_,
        bytes32[] memory proof_
    ) public view returns (Roles) {
        for (uint256 role = 0; role < uint8(Roles.PUBLIC); role++) {
            if (_isRole(Roles(role), user_, proof_)) return Roles(role);
        }

        return Roles.PUBLIC;
    }

    /**
     * Retrieve user's role, only called by front end
     * @param user_ user's address to check role
     * @param proof_ an array of merkle proofs for user's address
     */
    function getRoleFromProofs(
        address user_,
        bytes32[][4] memory proof_
    ) external view returns (Roles) {
        for (uint256 role = 0; role < uint8(Roles.PUBLIC); role++) {
            if (_isRole(Roles(role), user_, proof_[role])) return Roles(role);
        }

        return Roles.PUBLIC;
    }

    /**
     * Owner-only function to set current phase
     * @param phase_ Current phase to be set
     */
    function setCurrentPhase(uint phase_) external onlyOwner {
        if (!(Phases(phase_) >= Phases.OG || Phases(phase_) <= Phases.PUBLIC)) {
            revert NotValidPhase(phase_);
        }
        _currentPhase = Phases(phase_);
    }

    /**
     * Updates collection size for this collection
     * @param collectionSize_ new collection size
     */
    function updateCollectionSize(uint256 collectionSize_) external onlyOwner {
        uint256 oldCollectionSize = _collectionSize;
        _collectionSize = collectionSize_;

        emit UpdateCollectionSize(oldCollectionSize, collectionSize_);
    }

    /**
     * Function to set the Phase configuration
     * @param phase_ Phase to be set
     * @param startTime_ Start time of Phase
     * @param endTime_  End time of Phase
     */
    function setPhaseConfig(
        uint phase_,
        uint32 startTime_,
        uint32 endTime_
    ) external onlyOwner {
        _phaseConfig[Phases(phase_)] = [startTime_, endTime_];

        emit SetPhaseConfig(phase_, startTime_, endTime_);
    }

    /**
     * Function to set merkleroot for all roles
     * @param role_ role to set merkle root
     * @param root_  merkle root
     */
    function setMerkleRoot(Roles role_, bytes32 root_) external onlyOwner {
        merkleRoot[Roles(role_)] = root_;

        emit SetMerkleRoot(Roles(role_), merkleRoot[Roles(role_)]);
    }

    /**
     * Mint free tokens, only can be called by contract owner
     * @param to_ address to mint tokens to
     * @param amount_ amount to mint
     */
    function devMint(address to_, uint256 amount_) external onlyOwner {
        if (to_ == address(0)) {
            revert ZeroAddress();
        }
        // Check if the total supply does not exceed the collection size
        if (!(totalSupply() + amount_ <= _collectionSize)) {
            revert ExceedsCollectionSize(
                totalSupply(),
                amount_,
                _collectionSize
            );
        }

        _mint(to_, amount_);
    }

    /**
     * Function to withdraw funds from contract
     * @param to_ address to withdraw funds to
     */
    function withdrawAll(address payable to_) external onlyOwner {
        if (to_ == address(0)) {
            revert ZeroAddress();
        }
        to_.transfer(address(this).balance);
    }

    // =========================================================================
    //                                 Metadata
    // =========================================================================
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    function setpreRevealURI(string calldata preRevealURI_) external onlyOwner {
        _preRevealURI = preRevealURI_;
    }

    function isRevealed(bool isReveal_) external onlyOwner {
        _isRevealed = isReveal_;
    }

    function getRevealedBool() public view returns (bool) {
        return _isRevealed;
    }

    /**
     * Function to retrieve the metadata uri for a given token. Reverts for tokens that don't exist.
     * @param tokenId Token Id to get metadata for
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        if (!_isRevealed) {
            return
                bytes(_preRevealURI).length != 0
                    ? string(
                        abi.encodePacked(
                            _preRevealURI,
                            _toString(tokenId + 1),
                            ".json"
                        )
                    )
                    : "";
        }
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(
                    abi.encodePacked(baseURI, _toString(tokenId + 1), ".json")
                )
                : "";
    }

    // =========================================================================
    //                                  ERC165
    // =========================================================================

    /**
     * Overridden supportsInterface with IERC721 support and ERC2981 support
     * @param interfaceId Interface Id to check
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721A, IERC721A, ERC2981) returns (bool) {
        // Supports the following `interfaceId`s:
        // - IERC165: 0x01ffc9a7
        // - IERC721: 0x80ac58cd
        // - IERC721Metadata: 0x5b5e139f
        // - IERC2981: 0x2a55205a
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    // =========================================================================
    //                           Operator filtering
    // =========================================================================

    /**
     * Overridden setApprovalForAll with operator filtering.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override(ERC721A, IERC721A) onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * Overridden approve with operator filtering.
     */
    function approve(
        address operator,
        uint256 tokenId
    )
        public
        payable
        override(ERC721A, IERC721A)
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    /**
     * Overridden transferFrom with operator filtering. For ERC721A, this will also add
     * operator filtering for both safeTransferFrom functions.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721A, IERC721A) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    /**
     * Owner-only function to toggle operator filtering.
     * @param value Whether operator filtering is on/off.
     */
    function setOperatorFilteringEnabled(bool value) public onlyOwner {
        operatorFilteringEnabled = value;
    }

    // =========================================================================
    //                                 ERC2891
    // =========================================================================

    /**
     * Owner-only function to set the royalty receiver and royalty rate
     * @param receiver Address that will receive royalties
     * @param feeNumerator Royalty amount in basis points. Denominated by 10000
     */
    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        if (receiver == address(0)) {
            revert ZeroAddress();
        }
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // =========================================================================
    //                              Minting Logic
    // =========================================================================

    /**
     * Mint function.
     * @param amount_ amount of tokens to mint
     * @param proof_  proof for merkle root validation
     */
    function mint(uint256 amount_, bytes32[] memory proof_) external payable {
        //Check if contract is paused
        if (isPaused) {
            revert IsPaused();
        }

        // Check if the user is eligible to mint
        if (!(getMintEligibilityAtCurrentPhase(msg.sender, proof_))) {
            revert NotEligibleToMint(
                msg.sender,
                getRole(msg.sender, proof_),
                _currentPhase
            );
        }

        // Check the maximum mintable amount based on the current phase
        if (!(amount_ <= getMintable(msg.sender))) {
            revert ExeedsUsersMintLimit(
                msg.sender,
                amount_,
                getMintable(msg.sender)
            );
        }

        // Check if the total supply does not exceed the collection size
        if (!(totalSupply() + amount_ <= _collectionSize)) {
            revert ExceedsCollectionSize(
                totalSupply(),
                amount_,
                _collectionSize
            );
        }

        // Calculate the total mint price based on the current phase and amount
        uint256 mintPrice = calculateTotalMintPrice(
            msg.sender,
            amount_,
            proof_
        );

        // Check if the user has sent enough Ether to cover the mint price
        if (!(msg.value == mintPrice)) {
            revert InsufficientFunds(msg.sender, msg.value, mintPrice);
        }

        if (_currentPhase == Phases.PUBLIC) {
            numberMintedPublicSales[msg.sender] += amount_;
        }
        // Mint the specified amount of tokens to the user
        _mint(msg.sender, amount_);
    }

    /**
     * Retrieves current phase info
     * @return phase current phase
     * @return startTime start time of current phase
     * @return endTime end time of current phase
     */
    function getCurrentPhase()
        external
        view
        returns (Phases phase, uint32 startTime, uint32 endTime)
    {
        phase = Phases(_currentPhase);
        startTime = _phaseConfig[Phases(phase)][0];
        endTime = _phaseConfig[Phases(phase)][1];

        return (phase, startTime, endTime);
    }

    /**
     * Retrievs collection size and total supply
     * @return collectionSize collection size
     * @return totalSupply_ existing total supply
     */
    function getSupplyInfo()
        external
        view
        returns (uint256 collectionSize, uint256 totalSupply_)
    {
        collectionSize = _collectionSize;
        totalSupply_ = totalSupply();

        return (collectionSize, totalSupply_);
    }

    /**
     * Retrieves total mint price for user's desired amount
     * @param user_ user to calculate mint price
     * @param amount_ amount to calculate
     * @param proof_ user's merkle proof
     */
    function calculateTotalMintPrice(
        address user_,
        uint256 amount_,
        bytes32[] memory proof_
    ) public view returns (uint256 totalMintPrice) {
        bool mintEligibility = getMintEligibilityAtCurrentPhase(user_, proof_);
        if (!(mintEligibility)) {
            revert NotEligibleToMint(
                user_,
                getRole(user_, proof_),
                _currentPhase
            );
        }
        uint256 mintable = getMintable(user_);
        if (!(amount_ <= mintable)) {
            revert ExeedsUsersMintLimit(user_, amount_, getMintable(user_));
        }
        if (amount_ == 0) {
            return 0;
        }

        Roles role = getRole(user_, proof_);
        /**********OG Phase**********/
        //OG_Honoured and OG roles can mint
        if (_currentPhase == Phases.OG) {
            if (role == Roles.OG_HONOURED) {
                // No cost for minting for OG_HONOURED role
                return totalMintPrice = 0;
            } else if (role == Roles.OG) {
                if (mintable == 2 && (amount_ == 2 || amount_ == 1)) {
                    return totalMintPrice = OGMintPrice;
                }
                //user has minted 1 before
                else if (mintable == 1) {
                    return totalMintPrice = 0;
                }
            }
        }
        /**********WL Phase**********/
        //WL and Allowlist roles can mint
        else if (_currentPhase == Phases.WL) {
            if (role == Roles.WL) {
                if (mintable == 2 && (amount_ == 2 || amount_ == 1)) {
                    return totalMintPrice = standardMintPrice;
                } else if (mintable == 1) {
                    return totalMintPrice = 0;
                }
            } else if (role == Roles.ALLOWLIST) {
                return totalMintPrice = amount_ * standardMintPrice;
            }
        }

        /**********Public Phase**********/
        //Everyone can mint
        return totalMintPrice = amount_ * standardMintPrice;
    }

    /**
     * Retrieves number of available mint for user
     * @param _user user's address to check
     */
    function getMintable(address _user) public view returns (uint256 mintable) {
        uint256 numberMinted;
        if (_currentPhase != Phases.PUBLIC) {
            numberMinted = _numberMinted(_user);
        } else {
            numberMinted = numberMintedPublicSales[_user];
        }

        unchecked {
            mintable = maxMintPerWallet - numberMinted;
            if (mintable > maxMintPerWallet) {
                revert Overflow(mintable, maxMintPerWallet);
            }
        }
        return mintable;
    }

    function setPauseContract(bool pause_) external onlyOwner {
        isPaused = pause_;
    }

    function getMintEligibilityAtCurrentPhase(
        address user_,
        bytes32[] memory proof_
    ) public view returns (bool mintEligibility) {
        Roles role = getRole(user_, proof_);
        mintEligibility = false;
        if (_currentPhase == Phases.OG) {
            if (role == Roles.OG_HONOURED || role == Roles.OG) {
                mintEligibility = true;
            }
        } else if (_currentPhase == Phases.WL) {
            if (role == Roles.WL || role == Roles.ALLOWLIST) {
                mintEligibility = true;
            }
        } else if (_currentPhase == Phases.PUBLIC) {
            mintEligibility = true;
        }

        return mintEligibility;
    }

    /* ============ Internal Functions ============ */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function _isRole(
        Roles role_,
        address user_,
        bytes32[] memory proof_
    ) internal view returns (bool) {
        if (role_ == Roles.OG_HONOURED) {
            return _isOGHonoured(user_, proof_);
        } else if (role_ == Roles.OG) {
            return _isOG(user_, proof_);
        } else if (role_ == Roles.WL) {
            return _isWL(user_, proof_);
        } else if (role_ == Roles.ALLOWLIST) {
            return _isAllowlist(user_, proof_);
        }
        revert("Role does not exist");
    }

    function _isOGHonoured(
        address user_,
        bytes32[] memory proof_
    ) internal view returns (bool) {
        return _verify(proof_, user_, merkleRoot[Roles.OG_HONOURED]);
    }

    function _isOG(
        address user_,
        bytes32[] memory proof_
    ) internal view returns (bool) {
        return _verify(proof_, user_, merkleRoot[Roles.OG]);
    }

    function _isWL(
        address user_,
        bytes32[] memory proof_
    ) internal view returns (bool) {
        return _verify(proof_, user_, merkleRoot[Roles.WL]);
    }

    function _isAllowlist(
        address user_,
        bytes32[] memory proof_
    ) internal view returns (bool) {
        return _verify(proof_, user_, merkleRoot[Roles.ALLOWLIST]);
    }

    /**
     * Internal function to get merkle tree verification result
     * @param proof_ Merkle proof for validation
     * @param user_  Address of user for validation
     * @param root_  Merkle root hash
     */
    function _verify(
        bytes32[] memory proof_,
        address user_,
        bytes32 root_
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(user_))));
        bool verifyResult = MerkleProof.verify(proof_, root_, leaf);
        if (verifyResult) return true;
        else return false;
    }
}
