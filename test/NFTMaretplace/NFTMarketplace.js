const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace", function () {
    let marketplace;
    let nft;
    let deployer, seller, buyer;

    beforeEach(async () => {
        [deployer, seller, buyer] = await ethers.getSigners();

        const NFT = await ethers.getContractFactory("GSOEToken");
        nft = await NFT.connect(deployer).deploy();
        await nft.deployed();

        const Marketplace = await ethers.getContractFactory("NFTMarketplace");
        marketplace = await Marketplace.connect(deployer).deploy(nft.address);
        await marketplace.deployed();

        const MINTER_ROLE = await nft.MINTER_ROLE();
        await nft.connect(deployer).grantRole(MINTER_ROLE, marketplace.address);
    });



    it("should mint and list NFTs", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");
        const royalty = 5;
        const quantity = 1;

        await expect(
            marketplace.connect(seller).mintAndList(uri, price, royalty, quantity, {
                value: ethers.utils.parseEther("0.025"),
            })
        ).to.emit(marketplace, "MarketItemCreated");

        const items = await marketplace.fetchMarketItems();
        expect(items.length).to.equal(1);
        expect(items[0].price).to.equal(price);
    });

    it("should allow buying an NFT", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");
        const royalty = 5;

        await marketplace.connect(seller).mintAndList(uri, price, royalty, 1, {
            value: ethers.utils.parseEther("0.025"),
        });

        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        await expect(
            marketplace.connect(buyer).buyItem(listingId, { value: price })
        ).to.emit(marketplace, "MarketItemSold");

        const updated = await marketplace.idToMarketItem(listingId);
        expect(updated.sold).to.equal(true);
        expect(updated.owner).to.equal(buyer.address);
    });

    it("should return NFTs owned by buyer in fetchMyNFTs", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");
        const royalty = 5;

        // Seller mints and lists
        await marketplace.connect(seller).mintAndList(uri, price, royalty, 1, {
            value: ethers.utils.parseEther("0.025"),
        });

        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        // Buyer buys the NFT
        await marketplace.connect(buyer).buyItem(listingId, { value: price });

        // Fetch NFTs owned by buyer
        const buyerNFTs = await marketplace.connect(buyer).fetchMyNFTs();

        expect(buyerNFTs.length).to.equal(1);
        expect(buyerNFTs[0].owner).to.equal(buyer.address);
        expect(buyerNFTs[0].listingId).to.equal(listingId);
    });

    it("should return NFTs listed by seller in fetchItemsListed", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");
        const royalty = 5;

        // Seller mints and lists two NFTs
        await marketplace.connect(seller).mintAndList(uri, price, royalty, 1, {
            value: ethers.utils.parseEther("0.025"),
        });
        await marketplace.connect(seller).mintAndList(uri, price, royalty, 1, {
            value: ethers.utils.parseEther("0.025"),
        });

        // Fetch NFTs listed by seller
        const listedNFTs = await marketplace.connect(seller).fetchItemsListed();

        expect(listedNFTs.length).to.equal(2);
        listedNFTs.forEach((nft) => {
            expect(nft.seller).to.equal(seller.address);
        });
    });


    it("should allow delisting of unsold items", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");
        const royalty = 5;

        await marketplace.connect(seller).mintAndList(uri, price, royalty, 1, {
            value: ethers.utils.parseEther("0.025"),
        });

        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        await expect(
            marketplace.connect(seller).delistItem(listingId)
        ).to.emit(marketplace, "MarketItemDelisted");

        const listing = await marketplace.idToMarketItem(listingId);
        expect(listing.tokenId).to.equal(0); // Indicates deletion
    });
    it("should track total marketplace earnings", async () => {
        const uri = "ipfs://mocked-uri";
        const price = ethers.utils.parseEther("1");

        await marketplace.connect(seller).mintAndList(uri, price, 0, 1, {
            value: ethers.utils.parseEther("0.025"),
        });

        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        await marketplace.connect(buyer).buyItem(listingId, { value: price });

        const earnings = await marketplace.getMarketplaceEarnings();
        const expected = price.mul(2).div(100); // 2% of 1 ether
        expect(earnings).to.equal(expected);
    });

});
