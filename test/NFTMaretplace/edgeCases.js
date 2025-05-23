const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketplace Edge Cases and Failure Conditions", function () {
    let nftContract, marketplace;
    let owner, seller, buyer, stranger;
    const listingPrice = ethers.utils.parseEther("0.025");
    const nftPrice = ethers.utils.parseEther("1");

    beforeEach(async () => {
        [owner, seller, buyer, stranger] = await ethers.getSigners();

        const NFT = await ethers.getContractFactory("GSOEToken");
        nftContract = await NFT.deploy();
        await nftContract.deployed();

        const Marketplace = await ethers.getContractFactory("NFTMarketplace");
        marketplace = await Marketplace.deploy(nftContract.address);
        await marketplace.deployed();

        // Grant marketplace MINTER_ROLE to mint through marketplace (if needed)
        await nftContract.grantRole(ethers.utils.id("MINTER_ROLE"), marketplace.address);
    });

    it("should revert unauthorized batch minting", async function () {
        await expect(
            nftContract.connect(stranger).mintBatch(
                stranger.address,
                "ipfs://token-uri",
                1,
                10
            )
        ).to.be.revertedWithCustomError(nftContract, "AccessControlUnauthorizedAccount")
            .withArgs(stranger.address, ethers.utils.id("MINTER_ROLE"));
    });


    it("should revert buying with insufficient funds", async function () {
        // Seller mints and lists
        await marketplace.connect(seller).mintAndList("ipfs://token-uri", nftPrice, 10, 1, { value: listingPrice });
        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        // Buyer tries to buy with less ETH than price
        await expect(
            marketplace.connect(buyer).buyItem(listingId, { value: ethers.utils.parseEther("0.5") })
        ).to.be.revertedWith("Wrong ETH amount");
    });

    it("should revert delisting by non-owner", async function () {
        // Seller mints and lists
        await marketplace.connect(seller).mintAndList("ipfs://token-uri", nftPrice, 10, 1, { value: listingPrice });
        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        // Stranger tries to delist
        await expect(
            marketplace.connect(stranger).delistItem(listingId)
        ).to.be.revertedWith("Only seller can delist");
    });

    it("should revert double buy attempt", async function () {
        // Seller mints and lists
        await marketplace.connect(seller).mintAndList("ipfs://token-uri", nftPrice, 10, 1, { value: listingPrice });
        const items = await marketplace.fetchMarketItems();
        const listingId = items[0].listingId;

        // Buyer1 buys successfully
        await marketplace.connect(buyer).buyItem(listingId, { value: nftPrice });

        // Buyer2 tries to buy again
        await expect(
            marketplace.connect(stranger).buyItem(listingId, { value: nftPrice })
        ).to.be.revertedWith("Item already sold");
    });

    it("should revert listing with zero price if disallowed", async function () {
        // If your marketplace does NOT allow zero price listings
        await expect(
            marketplace.connect(seller).mintAndList("ipfs://token-uri", 0, 10, 1, { value: listingPrice })
        ).to.be.revertedWith("Price must be > 0");

        // Otherwise if zero price allowed, change this test accordingly
    });

    it("should revert minting with invalid royalty (>100%)", async function () {
        await expect(
            marketplace.connect(seller).mintAndList("ipfs://token-uri", nftPrice, 101, 1, { value: listingPrice })
        ).to.be.revertedWith("Royalty too high");
    });
});
