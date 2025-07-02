// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {INFT} from "./interfaces/INFT.sol";
import {MarketplaceLib} from "./lib/MarketplaceLib.sol";

contract MarketplaceCore is
    ReentrancyGuard,
    Pausable,
    Ownable,
    IERC721Receiver
{
    using MarketplaceLib for *;

    INFT public nftContract;
    uint256 public listingPrice;
    uint256 public transferFee;
    uint256 public newListingId;
    uint256 public totalMarketplaceEarnings;
    uint256 public constant MAX_ROYALTY = 20; // If 20% is the max royalty you allow

    mapping(uint256 => MarketplaceLib.MarketItem) public idToMarketItem;
    mapping(uint256 => uint256[]) public tokenIdToListings;
    uint256[] public marketListingIds;
    mapping(address => uint256) public pendingWithdrawals;

    event MarketItemCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address seller,
        uint256 price,
        uint256 timestamp
    );
    event MarketItemSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address buyer,
        uint256 price,
        uint256 timestamp
    );
    event MarketItemDelisted(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address seller,
        uint256 timestamp
    );
    event Withdraw(address indexed user, uint256 amount);

    constructor(address nftAddress) Ownable(msg.sender) {
        nftContract = INFT(nftAddress);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function listItem(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(msg.value == listingPrice, "Listing fee required");

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        _createMarketItems(tokenIds, price, msg.sender);
    }

    function batchListItems(
        uint256[] memory tokenIds,
        uint256 price
    ) external payable whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(
            msg.value == listingPrice * tokenIds.length,
            "Incorrect listing fee"
        );

        // Transfer each token from msg.sender to marketplace
        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftContract.safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i]
            );
        }

        _createMarketItems(tokenIds, price, msg.sender);
    }

    function _createMarketItems(
        uint256[] memory tokenIds,
        uint256 price,
        address seller
    ) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            (
                ,
                ,
                /* uint256 batchNumber */
                /* uint256 batchSpecificId */
                uint256 royaltyPercentage,
                address creator /* uint256 createdAt */,

            ) = nftContract.getTokenInfo(tokenId);

            newListingId++;

            MarketplaceLib.MarketItem memory item;
            item.listingId = newListingId;
            item.tokenId = tokenId;
            item.seller = payable(seller);
            item.creator = payable(creator);
            item.owner = address(this);
            item.price = price;
            item.royaltyPercentage = royaltyPercentage;
            item.sold = false;
            item.listedAt = block.timestamp;
            item.active = true;

            idToMarketItem[newListingId] = item;
            tokenIdToListings[tokenId].push(newListingId);
            marketListingIds.push(newListingId);

            emit MarketItemCreated(
                newListingId,
                tokenId,
                seller,
                price,
                block.timestamp
            );
        }
    }

    function buyItem(
        uint256 listingId
    ) external payable nonReentrant whenNotPaused {
        MarketplaceLib.MarketItem storage item = idToMarketItem[listingId];
        require(!item.sold, "Item already sold");
        require(msg.value == item.price, "Wrong ETH amount");

        uint256 fee = (item.price * transferFee) / 100;
        uint256 royaltyAmount = (item.price * item.royaltyPercentage) / 100;
        uint256 sellerProceeds = item.price - fee - royaltyAmount;
        totalMarketplaceEarnings += fee;

        pendingWithdrawals[item.seller] += sellerProceeds;
        pendingWithdrawals[item.creator] += royaltyAmount;
        pendingWithdrawals[owner()] += fee;

        item.sold = true;
        item.active = false; // <--- Add this line to mark as inactive after purchase
        item.owner = msg.sender;

        nftContract.safeTransferFrom(address(this), msg.sender, item.tokenId);

        emit MarketItemSold(
            listingId,
            item.tokenId,
            msg.sender,
            item.price,
            block.timestamp
        );
    }

    function setTransferFee(uint256 _fee) external onlyOwner {
        require(_fee + MAX_ROYALTY <= 100, "Fee too high"); // protect seller proceeds
        transferFee = _fee;
    }

    function updateFees(
        uint256 _listingPrice,
        uint256 _transferFee
    ) external onlyOwner {
        listingPrice = _listingPrice;
        transferFee = _transferFee;
    }

    function getFees() external view returns (uint256, uint256) {
        return (listingPrice, transferFee);
    }

    function delistItem(uint256 listingId) external nonReentrant whenNotPaused {
        MarketplaceLib.MarketItem storage item = idToMarketItem[listingId];
        require(item.seller == msg.sender, "Only seller can delist");
        require(!item.sold, "Already sold");

        nftContract.safeTransferFrom(address(this), msg.sender, item.tokenId);
        idToMarketItem[listingId].active = false;

        emit MarketItemDelisted(
            listingId,
            item.tokenId,
            msg.sender,
            block.timestamp
        );
    }

    function relistItem(
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant whenNotPaused {
        require(price > 0, "Price must be > 0");
        require(msg.value == listingPrice, "Listing fee required");
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        _createMarketItems(tokenIds, price, msg.sender);
    }

    function getActiveListing(
        uint256 tokenId
    ) external view returns (MarketplaceLib.MarketItem memory) {
        uint256[] memory listings = tokenIdToListings[tokenId];
        for (uint256 i = listings.length; i > 0; i--) {
            MarketplaceLib.MarketItem memory item = idToMarketItem[
                listings[i - 1]
            ];
            if (item.active && !item.sold) {
                return item;
            }
        }
        revert("No active listing");
    }

    function _isActive(
        MarketplaceLib.MarketItem storage item
    ) internal view returns (bool) {
        return item.active && !item.sold;
    }

    function getMarketItemCount() external view returns (uint256) {
        return marketListingIds.length; // or however you track total items
    }
    function getActiveMarketItems()
        external
        view
        returns (MarketplaceLib.MarketItem[] memory)
    {
        uint256 count = MarketplaceLib.countItems(
            marketListingIds,
            idToMarketItem,
            _isActive
        );
        MarketplaceLib.MarketItem[]
            memory items = new MarketplaceLib.MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < marketListingIds.length; i++) {
            MarketplaceLib.MarketItem storage item = idToMarketItem[
                marketListingIds[i]
            ];
            if (_isActive(item)) {
                items[index] = item;
                index++;
            }
        }
        return items;
    }

    function _isSoldAndOwnedBy(
        MarketplaceLib.MarketItem storage item,
        address user
    ) internal view returns (bool) {
        return item.sold && nftContract.ownerOf(item.tokenId) == user;
    }

    function getSoldItemsOwnedBy(
        address user
    ) external view returns (MarketplaceLib.MarketItem[] memory) {
        MarketplaceLib.MarketItem[]
            memory temp = new MarketplaceLib.MarketItem[](
                marketListingIds.length
            );
        uint256 index = 0;

        for (uint256 i = 0; i < marketListingIds.length; i++) {
            MarketplaceLib.MarketItem storage item = idToMarketItem[
                marketListingIds[i]
            ];
            if (_isSoldAndOwnedBy(item, user)) {
                temp[index] = item;
                index++;
            }
        }

        // Create final array of correct size
        MarketplaceLib.MarketItem[]
            memory result = new MarketplaceLib.MarketItem[](index);
        for (uint256 i = 0; i < index; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    function getItemsListedBy(
        address seller
    ) external view returns (MarketplaceLib.MarketItem[] memory) {
        uint256 total = marketListingIds.length;
        uint256 count = 0;

        // First count how many listings belong to seller
        for (uint256 i = 0; i < total; i++) {
            MarketplaceLib.MarketItem storage item = idToMarketItem[
                marketListingIds[i]
            ];
            if (item.seller == seller) {
                count++;
            }
        }

        MarketplaceLib.MarketItem[]
            memory result = new MarketplaceLib.MarketItem[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < total; i++) {
            MarketplaceLib.MarketItem storage item = idToMarketItem[
                marketListingIds[i]
            ];
            if (item.seller == seller) {
                result[index] = item;
                index++;
            }
        }
        return result;
    }

    function getMarketplaceEarnings() external view returns (uint256) {
        return totalMarketplaceEarnings;
    }

    function setListingPrice(uint256 _price) external onlyOwner {
        listingPrice = _price;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFunds() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");

        emit Withdraw(msg.sender, amount);
    }
}
