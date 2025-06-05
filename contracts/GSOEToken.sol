// GSOEToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract GSOEToken is ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 private _tokenIds;
    uint256 public currentBatchNumber = 1;

    mapping(uint256 => uint256) public batchNumberOf;
    mapping(uint256 => uint256) public batchSpecificIdOf;
    mapping(uint256 => uint256) public royaltyPercentageOf;
    mapping(uint256 => address) public creatorOf;

    event BatchMinted(
        uint256 batchNumber,
        address to,
        uint256[] tokenIds,
        uint256 royaltyPercentage,
        address creator
    );

    constructor() ERC721("Greatest Show On Earth", "GSOE") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mintBatch(
        address to,
        string memory tokenURI,
        uint256 quantity,
        uint256 royaltyPercentage
    ) external onlyRole(MINTER_ROLE) returns (uint256[] memory) {
        require(quantity > 0, "Quantity must be at least 1");
        require(royaltyPercentage <= 100, "Royalty too high");

        uint256[] memory newTokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds++;
            uint256 newTokenId = _tokenIds;

            _mint(to, newTokenId);
            _setTokenURI(newTokenId, tokenURI);

            royaltyPercentageOf[newTokenId] = royaltyPercentage;
            batchSpecificIdOf[newTokenId] = i + 1;
            batchNumberOf[newTokenId] = currentBatchNumber;

            creatorOf[newTokenId] = to; // store creator here

            newTokenIds[i] = newTokenId;
        }

        emit BatchMinted(
            currentBatchNumber,
            to,
            newTokenIds,
            royaltyPercentage,
            to
        );

        currentBatchNumber++;
        return newTokenIds;
    }

    function getTokenInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 batchNumber,
            uint256 batchSpecificId,
            uint256 royaltyPercentage,
            address creator
        )
    {
        return (
            batchNumberOf[tokenId],
            batchSpecificIdOf[tokenId],
            royaltyPercentageOf[tokenId],
            creatorOf[tokenId]
        );
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
