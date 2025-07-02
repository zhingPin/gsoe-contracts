// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {MarketplaceLib} from "../lib/MarketplaceLib.sol";

interface IMarketplaceCore {
    function marketListingIds(uint256 index) external view returns (uint256);

    function idToMarketItem(
        uint256 id
    )
        external
        view
        returns (
            uint256 listingId,
            uint256 tokenId,
            address payable seller,
            address payable creator,
            address owner,
            uint256 price,
            uint256 royaltyPercentage,
            bool sold,
            uint256 listedAt,
            bool active
        );

    function listingPrice() external view returns (uint256);
    function transferFee() external view returns (uint256);
    function totalMarketplaceEarnings() external view returns (uint256);
    function nftContract() external view returns (address);
    function getMarketItemCount() external view returns (uint256);

    function getActiveListing(
        uint256 tokenId
    ) external view returns (MarketplaceLib.MarketItem memory);

    function getActiveMarketItems()
        external
        view
        returns (MarketplaceLib.MarketItem[] memory);

    function getSoldItemsOwnedBy(
        address user
    ) external view returns (MarketplaceLib.MarketItem[] memory);

    function getItemsListedBy(
        address seller
    ) external view returns (MarketplaceLib.MarketItem[] memory);
}
