const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFTMarketMinter", function () {
    let nftMarketMinter, gsoeToken, owner, minter;
    const tokenURI = "ipfs://example-uri";
    const price = ethers.utils.parseEther("1");
    const royaltyPercentage = 10;
    const quantity = 2;

    beforeEach(async () => {
        [owner, minter] = await ethers.getSigners();

        const GSOEToken = await ethers.getContractFactory("GSOEToken");
        gsoeToken = await GSOEToken.deploy();
        await gsoeToken.deployed();

        const NFTMarketMinter = await ethers.getContractFactory("NFTMarketMinter");
        nftMarketMinter = await NFTMarketMinter.deploy(gsoeToken.address);
        await nftMarketMinter.deployed();

        // Grant minter role if needed
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.grantRole(MINTER_ROLE, nftMarketMinter.address);

        // Set listingPrice and mintFee as needed
        await nftMarketMinter.setListingPrice(ethers.utils.parseEther("0.01"));
        // mintFee is inside gsoeToken
    });

    it("Should mint and list batch of NFTs", async () => {
        const mintFee = await gsoeToken.mintFee();
        const listingPrice = await nftMarketMinter.listingPrice();

        const totalFee = mintFee.mul(quantity).add(listingPrice.mul(quantity));

        const tx = await nftMarketMinter.connect(minter).mintAndList(
            tokenURI,
            price,
            royaltyPercentage,
            quantity,
            { value: totalFee }
        );

        const receipt = await tx.wait();

        // Event check
        const event = receipt.events.find(e => e.event === "BatchMintAndListed");
        expect(event).to.exist;
        expect(event.args.minter).to.equal(minter.address);
        expect(event.args.price).to.equal(price);
        expect(event.args.tokenIds.length).to.equal(quantity);

        // Verify tokens minted & owned by marketplace contract
        for (const tokenId of event.args.tokenIds) {
            expect(await gsoeToken.ownerOf(tokenId)).to.equal(nftMarketMinter.address);
            // Check listed items for each tokenId...
        }
    });

    it("Should revert on empty tokenURI", async () => {
        await expect(
            nftMarketMinter.mintAndList(
                "",
                price,
                royaltyPercentage,
                quantity,
                { value: 0 }
            )
        ).to.be.revertedWith("tokenURI must not be empty");
    });

    it("Should revert if quantity is zero", async () => {
        await expect(
            nftMarketMinter.mintAndList(
                tokenURI,
                price,
                royaltyPercentage,
                0,
                { value: 0 }
            )
        ).to.be.revertedWith("Quantity must be at least 1");
    });

    it("Should revert if price is zero", async () => {
        await expect(
            nftMarketMinter.mintAndList(
                tokenURI,
                0,
                royaltyPercentage,
                quantity,
                { value: 0 }
            )
        ).to.be.revertedWith("Price must be > 0");
    });

    it("Should revert if msg.value is incorrect", async () => {
        const mintFee = await gsoeToken.mintFee();
        const listingPrice = await nftMarketMinter.listingPrice();

        const wrongFee = mintFee.mul(quantity); // missing listing fee

        await expect(
            nftMarketMinter.connect(minter).mintAndList(
                tokenURI,
                price,
                royaltyPercentage,
                quantity,
                { value: wrongFee }
            )
        ).to.be.revertedWith("Incorrect total fee");
    });
});
