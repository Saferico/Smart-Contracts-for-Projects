// SPDX-License-Identifier: MIT

// Based on open zeppelin ERC721 and inspired by squeebo's improvements


 

pragma solidity ^0.8.0;


 

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/utils/Context.sol";

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


 

abstract contract ERC721C is Context, ERC165, IERC721, IERC721Metadata {

    using Address for address;

    using Strings for uint256;


 

    // Token name

    string private _name;


 

    // Token symbol

    string private _symbol;


 

    // Mapping from token ID to owner address

    address[] internal _owners;


 

    // Mapping owner address to token count

    mapping(address => uint256) private _balances;


 

    // Mapping from token ID to approved address

    mapping(uint256 => address) private _tokenApprovals;


 

    // Mapping from owner to operator approvals

    mapping(address => mapping(address => bool)) private _operatorApprovals;


 

    /**

     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.

     */

    constructor(string memory name_, string memory symbol_) {

        _name = name_;

        _symbol = symbol_;

    }


 

    /**

     * @dev See {IERC165-supportsInterface}.

     */

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {

        return

            interfaceId == type(IERC721).interfaceId ||

            interfaceId == type(IERC721Metadata).interfaceId ||

            super.supportsInterface(interfaceId);

    }


 

    /**

     * @dev See {IERC721-balanceOf}.

     */

    function balanceOf(address owner) public view virtual override returns (uint256) {

        require(owner != address(0), "ERC721: balance query for the zero address");

        return _balances[owner];

    }


 

    /**

     * @dev See {IERC721-ownerOf}.

     */

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {

        address owner = _owners[tokenId];

        require(owner != address(0), "ERC721: owner query for nonexistent token");

        return owner;

    }


 

    /**

     * @dev See {IERC721Metadata-name}.

     */

    function name() public view virtual override returns (string memory) {

        return _name;

    }


 

    /**

     * @dev See {IERC721Metadata-symbol}.

     */

    function symbol() public view virtual override returns (string memory) {

        return _symbol;

    }


 

    /**

     * @dev See {IERC721Metadata-tokenURI}.

     */

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {

        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");


 

        string memory baseURI = "";

        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";

    }


 

    /**

     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each

     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty

     * by default, can be overridden in child contracts.

     

    function _baseURI() internal view virtual returns (string memory) {

        return "";

    }*/


 

    /**

     * @dev See {IERC721-approve}.

     */

    function approve(address to, uint256 tokenId) public virtual override {

        address owner = ERC721C.ownerOf(tokenId);

        require(to != owner, "ERC721: approval to current owner");


 

        require(

            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),

            "ERC721: approve caller is not owner nor approved for all"

        );


 

        _approve(to, tokenId);

    }


 

    /**

     * @dev See {IERC721-getApproved}.

     */

    function getApproved(uint256 tokenId) public view virtual override returns (address) {

        require(_exists(tokenId), "ERC721: approved query for nonexistent token");


 

        return _tokenApprovals[tokenId];

    }


 

    /**

     * @dev See {IERC721-setApprovalForAll}.

     */

    function setApprovalForAll(address operator, bool approved) public virtual override {

        _setApprovalForAll(_msgSender(), operator, approved);

    }


 

    /**

     * @dev See {IERC721-isApprovedForAll}.

     */

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {

        return _operatorApprovals[owner][operator];

    }


 

    /**

     * @dev See {IERC721-transferFrom}.

     */

    function transferFrom(

        address from,

        address to,

        uint256 tokenId

    ) public virtual override {

        //solhint-disable-next-line max-line-length

        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");


 

        _transfer(from, to, tokenId);

    }


 

    /**

     * @dev See {IERC721-safeTransferFrom}.

     */

    function safeTransferFrom(

        address from,

        address to,

        uint256 tokenId

    ) public virtual override {

        safeTransferFrom(from, to, tokenId, "");

    }


 

    /**

     * @dev See {IERC721-safeTransferFrom}.

     */

    function safeTransferFrom(

        address from,

        address to,

        uint256 tokenId,

        bytes memory _data

    ) public virtual override {

        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _safeTransfer(from, to, tokenId, _data);

    }


 

    /**

     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients

     * are aware of the ERC721 protocol to prevent tokens from being forever locked.

     *

     * `_data` is additional data, it has no specified format and it is sent in call to `to`.

     *

     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.

     * implement alternative mechanisms to perform token transfer, such as signature-based.

     *

     * Requirements:

     *

     * - `from` cannot be the zero address.

     * - `to` cannot be the zero address.

     * - `tokenId` token must exist and be owned by `from`.

     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.

     *

     * Emits a {Transfer} event.

     */

    function _safeTransfer(

        address from,

        address to,

        uint256 tokenId,

        bytes memory _data

    ) internal virtual {

        _transfer(from, to, tokenId);

        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");

    }


 

    /**

     * @dev Returns whether `tokenId` exists.

     *

     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.

     *

     * Tokens start existing when they are minted (`_mint`),

     * and stop existing when they are burned (`_burn`).

     */

    function _exists(uint256 tokenId) internal view virtual returns (bool) {

        return (tokenId < _owners.length && _owners[tokenId] != address(0));

    }


 

    /**

     * @dev Returns whether `spender` is allowed to manage `tokenId`.

     *

     * Requirements:

     *

     * - `tokenId` must exist.

     */

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {

        require(_exists(tokenId), "ERC721: operator query for nonexistent token");

        address owner = ERC721C.ownerOf(tokenId);

        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));

    }


 

    /**

     * @dev Safely mints `tokenId` and transfers it to `to`.

     *

     * Requirements:

     *

     * - `tokenId` must not exist.

     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.

     *

     * Emits a {Transfer} event.

     */

    function _safeMint(address to, uint256 tokenId) internal virtual {

        _safeMint(to, tokenId, "");

    }


 

    /**

     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is

     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.

     */

    function _safeMint(

        address to,

        uint256 tokenId,

        bytes memory _data

    ) internal virtual {

        _mint(to, tokenId);

        require(

            _checkOnERC721Received(address(0), to, tokenId, _data),

            "ERC721: transfer to non ERC721Receiver implementer"

        );

    }


 

    /**

     * @dev Mints `tokenId` and transfers it to `to`.

     *

     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible

     *

     * Requirements:

     *

     * - `tokenId` must not exist.

     * - `to` cannot be the zero address.

     *

     * Emits a {Transfer} event.

     */

    function _mint(address to, uint256 tokenId) internal virtual {

        require(to != address(0), "ERC721: mint to the zero address");

        require(!_exists(tokenId), "ERC721: token already minted");


 

        _beforeTokenTransfer(address(0), to, tokenId);


 

        _balances[to] += 1;

        _owners.push(to);


 

        emit Transfer(address(0), to, tokenId);


 

        _afterTokenTransfer(address(0), to, tokenId);

    }


 

    /**

     * @dev Destroys `tokenId`.

     * The approval is cleared when the token is burned.

     *

     * Requirements:

     *

     * - `tokenId` must exist.

     *

     * Emits a {Transfer} event.

     */

    function _burn(uint256 tokenId) internal virtual {

        address owner = ERC721C.ownerOf(tokenId);


 

        _beforeTokenTransfer(owner, address(0), tokenId);


 

        // Clear approvals

        _approve(address(0), tokenId);


 

        _balances[owner] -= 1;

        _owners[tokenId] = address(0);


 

        emit Transfer(owner, address(0), tokenId);


 

        _afterTokenTransfer(owner, address(0), tokenId);

    }


 

    /**

     * @dev Transfers `tokenId` from `from` to `to`.

     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.

     *

     * Requirements:

     *

     * - `to` cannot be the zero address.

     * - `tokenId` token must be owned by `from`.

     *

     * Emits a {Transfer} event.

     */

    function _transfer(

        address from,

        address to,

        uint256 tokenId

    ) internal virtual {

        require(ERC721C.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        require(to != address(0), "ERC721: transfer to the zero address");


 

        _beforeTokenTransfer(from, to, tokenId);


 

        // Clear approvals from the previous owner

        _approve(address(0), tokenId);


 

        _balances[from] -= 1;

        _balances[to] += 1;

        _owners[tokenId] = to;


 

        emit Transfer(from, to, tokenId);


 

        _afterTokenTransfer(from, to, tokenId);

    }


 

    /**

     * @dev Approve `to` to operate on `tokenId`

     *

     * Emits a {Approval} event.

     */

    function _approve(address to, uint256 tokenId) internal virtual {

        _tokenApprovals[tokenId] = to;

        emit Approval(ERC721C.ownerOf(tokenId), to, tokenId);

    }


 

    /**

     * @dev Approve `operator` to operate on all of `owner` tokens

     *

     * Emits a {ApprovalForAll} event.

     */

    function _setApprovalForAll(

        address owner,

        address operator,

        bool approved

    ) internal virtual {

        require(owner != operator, "ERC721: approve to caller");

        _operatorApprovals[owner][operator] = approved;

        emit ApprovalForAll(owner, operator, approved);

    }


 

    /**

     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.

     * The call is not executed if the target address is not a contract.

     *

     * @param from address representing the previous owner of the given token ID

     * @param to target address that will receive the tokens

     * @param tokenId uint256 ID of the token to be transferred

     * @param _data bytes optional data to send along with the call

     * @return bool whether the call correctly returned the expected magic value

     */

    function _checkOnERC721Received(

        address from,

        address to,

        uint256 tokenId,

        bytes memory _data

    ) private returns (bool) {

        if (to.isContract()) {

            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {

                return retval == IERC721Receiver.onERC721Received.selector;

            } catch (bytes memory reason) {

                if (reason.length == 0) {

                    revert("ERC721: transfer to non ERC721Receiver implementer");

                } else {

                    assembly {

                        revert(add(32, reason), mload(reason))

                    }

                }

            }

        } else {

            return true;

        }

    }


 

    /**

     * @dev Hook that is called before any token transfer. This includes minting

     * and burning.

     *

     * Calling conditions:

     *

     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be

     * transferred to `to`.

     * - When `from` is zero, `tokenId` will be minted for `to`.

     * - When `to` is zero, ``from``'s `tokenId` will be burned.

     * - `from` and `to` are never both zero.

     *

     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].

     */

    function _beforeTokenTransfer(

        address from,

        address to,

        uint256 tokenId

    ) internal virtual {}


 

    /**

     * @dev Hook that is called after any transfer of tokens. This includes

     * minting and burning.

     *

     * Calling conditions:

     *

     * - when `from` and `to` are both non-zero.

     * - `from` and `to` are never both zero.

     *

     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].

     */

    function _afterTokenTransfer(

        address from,

        address to,

        uint256 tokenId

    ) internal virtual {}

}


 

    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////////////////////  


 

pragma solidity ^0.8.0;


 

contract ForeverYUNN is Ownable, ERC721C {


 

    using Strings for uint256;

    using ECDSA for bytes32;


 

    uint private constant TOTAL_SUPPLY = 100;

    uint private constant FOUNDER_MAX_MINT = 1000;


 

    //  1 = preparaion phase, 2 = presale, 3 = public sale, 4 = no sale any more

    uint internal  _saleStatus = 1;

   

    uint internal  _presalePrice  = 0.001 ether;

    uint internal  _publicsalePrice = 0.001 ether;

    uint internal  _publicsaleStart;


 

    bool internal _revealed;

    string internal _baseURI;

    string internal _contractURI;


 

    address internal _treasuryAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;

    address internal _signerAddress = 0xb018d568cc2DDFA152F30F94290D3cCD9b120B70;


 

    uint16 internal  _tokensInTreasury;

   

    uint256 public tokenIdOffset;

    string public provenance;


 

    struct MintingGroup {

        uint8 groupId;

        uint mintPrice;

        uint16 userNftMax;

        uint16 txNftMax;

        uint16 groupNftAllowance;

        uint16 minted;

    }


 

    MintingGroup[] internal mintingGroups;


 

    constructor() ERC721C("Forever yunn", "YUNN") {

 

        // public sale users

        MintingGroup memory mg = MintingGroup(0, _publicsalePrice, 9999, 2, 10000, 0);

        mintingGroups.push(mg);

               

        // whitelisted users

        mg = MintingGroup(1, _presalePrice, 2, 2, 5642, 0);

        mintingGroups.push(mg);


 

        // OGS group users

        mg = MintingGroup(2, _presalePrice, 2, 2, 3000, 0);

        mintingGroups.push(mg);


 

        // partherships users

        mg = MintingGroup(3, _presalePrice, 1, 1, 1000, 0);

        mintingGroups.push(mg);  


 

        // halal certified users

        mg = MintingGroup(4, _presalePrice, 4, 4, 48, 0);

        mintingGroups.push(mg);  


 

        // head of moderators

        mg = MintingGroup(5, _presalePrice, 2, 2, 2, 0);

        mintingGroups.push(mg);                  


 

        // moderators

        mg = MintingGroup(6, _presalePrice, 3, 3, 42, 0);

        mintingGroups.push(mg);    


 

        // founders

        mg = MintingGroup(7, 0, 30, 30, 150, 0);

        mintingGroups.push(mg);  


 

    }


 

    function checkMintPass(bytes calldata mintPass, uint8 mintingGroupId) internal view returns(bool) {

        bytes32 hash = ECDSA.toEthSignedMessageHash(keccak256(abi.encodePacked(msg.sender, mintingGroupId)));

        return  (_signerAddress == hash.recover(mintPass));

    }


 

 

    /// PUBLIC PART //////////////////////////////////////////////////////////////////////////

    function mint(bytes calldata mintPass, uint8 mintingGroupId, uint16 numberOfTokens) external payable {

        require((mintingGroupId == 0 && _saleStatus == 3) || (mintingGroupId > 0 && _saleStatus == 2), "Group cannot mint in this phase");

        require(checkMintPass(mintPass, mintingGroupId), "Mint pass not valid");

        require(mintingGroupId < mintingGroups.length, "Minting group not valid");

        require(mintingGroups[mintingGroupId].mintPrice * numberOfTokens <= msg.value, "Ether value sent is not correct");

        require(numberOfTokens <= mintingGroups[mintingGroupId].txNftMax, "Exceeded tx max token purchase");

        require(balanceOf(msg.sender) + numberOfTokens <= mintingGroups[mintingGroupId].userNftMax, "Exceeded user max token purchase");

        require(mintingGroups[mintingGroupId].minted + numberOfTokens <= mintingGroups[mintingGroupId].groupNftAllowance, "Exceeded group max token purchase");

        require(_owners.length + numberOfTokens <= TOTAL_SUPPLY, "Purchase would exceed max tokens");

                   

        mintingGroups[mintingGroupId].minted = mintingGroups[mintingGroupId].minted + numberOfTokens;


 

        for (uint i = 0; i < numberOfTokens; i++) {

            _safeMint(msg.sender, _owners.length);

        }


 

        if (_owners.length == TOTAL_SUPPLY && tokenIdOffset == 0) {

            setTokenIdOffset();

        }

    }


 

    function tokenURI(uint256 tokenId) public view override returns (string memory) {

        require(_exists(tokenId), "URI query for nonexistent token");

        if (!_revealed) return _baseURI;

        return string(abi.encodePacked(_baseURI, tokenId.toString()));

    }  


 

    function minted() external view returns(uint16) {

        return (uint16( _owners.length));

    }    


 

    function contractURI() external view returns (string memory) {

        return _contractURI;

    }

   

    function burn (uint tokenId) external {

        require(_isApprovedOrOwner(msg.sender, tokenId), "burn caller is not owner nor approved");

        _burn(tokenId);

    }    

   

    function retMintedByGroups() external view returns(uint16[] memory) {

        uint16[] memory n = new uint16[] (mintingGroups.length + 1);

        for (uint8 i=0; i < mintingGroups.length; i++) {

            n[i] = mintingGroups[i].minted;

        }

        n[n.length-1] = _tokensInTreasury;

        return n;

    }

/*

    function offsetCalculationTimeLimit() public view returns(uint256 ) {

        require(_publicsaleStart > 0, "Time not set, public sale not started");

        return  _publicsaleStart + 86400 * 10;

    }

*/


 

    /// ADMIN PART ///////////////////////////////////////////////////////////////////////////

    function treasuryMint(uint16 numberOfTokens) external onlyOwner {

        require(_saleStatus == 2, "Treasury mint only in presale");

        require(_tokensInTreasury + numberOfTokens <= FOUNDER_MAX_MINT, "Founder max mint exceeded");

       

        _tokensInTreasury = _tokensInTreasury + numberOfTokens;

       

        for (uint i = 0; i < numberOfTokens; i++) {

            _safeMint(_treasuryAddress, _owners.length);

        }

    }


 

    function withdraw() external onlyOwner {

        address payable treasury = payable(_treasuryAddress);

        treasury.transfer(address(this).balance);

    }

/*

    function setStartingIndexBlock() external onlyOwner {

        require(startingIndexBlock == 0, "Starting index is already set");

        startingIndexBlock = block.number;

    }    

*/

    function setSaleStatus(uint256 status) external onlyOwner {

        require(status < 5, "Status value not valid");

        _saleStatus = status;

    }


 

    function setTreasuryAddress(address tAddress) external onlyOwner {

        require(tAddress != address(0), "Address is not valid");

        _treasuryAddress = tAddress;

    }


 

     function setProvenance(string calldata prov) external onlyOwner {

        provenance = prov;

    }  

   

    function setBaseURI(string memory baseURI) external onlyOwner {

        _baseURI = baseURI;

    }    


 

    function setContractURI(string calldata URI) external onlyOwner {

        _contractURI = URI;

    }    


 

    function setSignerAddress(address addr) external onlyOwner {

         require(addr != address(0), "Address is not valid");  

        _signerAddress = addr;

    }    


 

    function revealed(bool r) external onlyOwner {

        _revealed = r;

    }


 

    function setMintingGroup (uint8 mintingGroupId, uint mintPrice, uint16 userNftMax, uint16 txNftMax, uint16 groupNftAllowance ) external onlyOwner  {

        require(mintingGroupId < mintingGroups.length, "Minting group not valid");

        mintingGroups[mintingGroupId].mintPrice = mintPrice;

        mintingGroups[mintingGroupId].userNftMax = userNftMax;

        mintingGroups[mintingGroupId].userNftMax = userNftMax;

        mintingGroups[mintingGroupId].txNftMax = txNftMax;

        mintingGroups[mintingGroupId].groupNftAllowance = groupNftAllowance;

    }


 

    function burnReminingTokens () external onlyOwner {

        require (_saleStatus == 4, "Burning allowed only in post sale");

        for (uint i = _owners.length; i < TOTAL_SUPPLY; i++) {

            _owners[i] = address(0);

        }

    }    


 

    function setTokenIdOffset() public onlyOwner {

        require(_saleStatus == 3 || _saleStatus == 4, "setting offset not allowed now");

        require(tokenIdOffset == 0, "Offset already set");

       

        tokenIdOffset = uint(blockhash(block.number - 1)) % TOTAL_SUPPLY;


 

        if (tokenIdOffset == 0) {

            tokenIdOffset = 1;

        }

    }    


 

}