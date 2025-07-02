// INFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface INFT {
    function mintBatch(
        address to,
        string memory tokenURI,
        uint256 quantity,
        uint256 royaltyPercentage
    ) external returns (uint256[] memory);

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
            address creator
        );

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}
