// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MarketplaceLib {
    struct MarketItem {
        uint256 listingId;
        uint256 tokenId;
        address payable seller;
        address payable creator;
        address owner;
        uint256 price;
        uint256 royaltyPercentage;
        bool sold;
        uint256 listedAt;
        bool active;
    }

    // Count how many items satisfy the condition given by the callback
    function countItems(
        uint256[] storage allIds,
        mapping(uint256 => MarketItem) storage items,
        function(MarketItem storage) view returns (bool) condition
    ) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            if (condition(items[allIds[i]])) {
                count++;
            }
        }
        return count;
    }

    // Collect items that satisfy the condition given by the callback
    function filterItems(
        uint256[] storage allIds,
        mapping(uint256 => MarketItem) storage items,
        function(MarketItem storage) view returns (bool) condition
    ) internal view returns (MarketItem[] memory) {
        uint256 count = countItems(allIds, items, condition);
        MarketItem[] memory result = new MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allIds.length; i++) {
            MarketItem storage item = items[allIds[i]];
            if (condition(item)) {
                result[index] = item;
                index++;
            }
        }
        return result;
    }
}
