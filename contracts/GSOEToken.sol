// GSOEToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {NFTLib} from "./lib/NFTLib.sol";

contract GSOEToken is ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIds;
    uint256 public currentBatchNumber = 1;
    uint256 public mintFee = 0.01 ether;
    address public feeRecipient;

    mapping(uint256 => uint256) public batchNumberOf;
    mapping(uint256 => uint256) public batchSpecificIdOf;
    mapping(uint256 => uint256) public royaltyPercentageOf;
    mapping(uint256 => address) public creatorOf;
    mapping(uint256 => uint256) public createdAtOf;

    event BatchMinted(
        uint256 batchNumber,
        address to,
        uint256[] tokenIds,
        uint256 royaltyPercentage,
        address creator,
        uint256 createdAt // <-- add this
    );

    constructor() ERC721("Greatest Show On Earth", "GSOE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        feeRecipient = msg.sender; // or set a separate treasury
    }

    function setMintFee(
        uint256 _mintFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintFee = _mintFee;
    }

    function setFeeRecipient(
        address _recipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        feeRecipient = _recipient;
    }

    function mintBatch(
        address to,
        address creator,
        string memory tokenURI,
        uint256 quantity,
        uint256 royaltyPercentage
    ) external payable onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        require(quantity > 0, "Quantity must be at least 1");
        require(royaltyPercentage <= 100, "Royalty too high");
        require(msg.value == mintFee * quantity, "Incorrect minting fee");

        (bool sent, ) = feeRecipient.call{value: msg.value}("");
        require(sent, "Fee transfer failed");

        uint256[] memory newTokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds++;
            uint256 newTokenId = _tokenIds;

            _mint(to, newTokenId);
            _setTokenURI(newTokenId, tokenURI);

            royaltyPercentageOf[newTokenId] = royaltyPercentage;
            batchSpecificIdOf[newTokenId] = i + 1;
            batchNumberOf[newTokenId] = currentBatchNumber;

            creatorOf[newTokenId] = creator;

            newTokenIds[i] = newTokenId;
            createdAtOf[newTokenId] = block.timestamp;
        }

        emit BatchMinted(
            currentBatchNumber,
            to,
            newTokenIds,
            royaltyPercentage,
            creator,
            block.timestamp
        );

        currentBatchNumber++;
        return newTokenIds;
    }

    function getTokenMetadata(
        uint256 tokenId
    ) public view returns (NFTLib.TokenMetadata memory) {
        return
            NFTLib.TokenMetadata({
                batchNumber: batchNumberOf[tokenId],
                batchSpecificId: batchSpecificIdOf[tokenId],
                royaltyPercentage: royaltyPercentageOf[tokenId],
                creator: creatorOf[tokenId],
                createdAt: createdAtOf[tokenId]
            });
    }

    function getTokenInfo(
        uint256 tokenId
    ) external view returns (uint256, uint256, uint256, address, uint256) {
        NFTLib.TokenMetadata memory meta = getTokenMetadata(tokenId);
        return (
            meta.batchNumber,
            meta.batchSpecificId,
            meta.royaltyPercentage,
            meta.creator,
            meta.createdAt
        );
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // require(_ownerOf(tokenId) != address(0), "Token does not exist");

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
