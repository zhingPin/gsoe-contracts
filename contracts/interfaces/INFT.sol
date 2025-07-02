// INFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTLib} from "../lib/NFTLib.sol";

interface INFT {
    function mintBatch(
        address to,
        address creator,
        string memory tokenURI,
        uint256 quantity,
        uint256 royaltyPercentage
    ) external payable returns (uint256[] memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function getTokenInfo(
        uint256 tokenId
    )
        external
        view
        returns (
            uint256 batchNumber,
            uint256 batchSpecificId,
            uint256 royaltyPercentage,
            address creator,
            uint256 createdAt
        );

    function getTokenMetadata(
        uint256 tokenId
    ) external view returns (NFTLib.TokenMetadata memory);

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    function mintFee() external view returns (uint256);
}
