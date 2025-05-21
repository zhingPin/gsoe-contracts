// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IRoyaltyInfo {
    function getRoyaltyInfo(
        uint256 tokenId
    ) external view returns (address receiver, uint256 percentage);
}

contract RoyaltyInfoManager is IRoyaltyInfo {
    mapping(uint256 => address) public creatorOf;
    mapping(uint256 => uint256) public royaltyPercentageOf;

    function setRoyaltyInfo(
        uint256 tokenId,
        address creator,
        uint256 percentage
    ) external {
        // Add access control here if needed
        require(percentage <= 100, "Royalty too high");
        creatorOf[tokenId] = creator;
        royaltyPercentageOf[tokenId] = percentage;
    }

    function getRoyaltyInfo(
        uint256 tokenId
    ) external view override returns (address receiver, uint256 percentage) {
        return (creatorOf[tokenId], royaltyPercentageOf[tokenId]);
    }
}
