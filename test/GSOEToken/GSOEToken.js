const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GSOEToken contract", function () {
    let GSOEToken, gsoeToken, deployer, addr1;

    beforeEach(async function () {
        [deployer, addr1] = await ethers.getSigners();

        const GSOETokenFactory = await ethers.getContractFactory("GSOEToken");
        gsoeToken = await GSOETokenFactory.deploy();
        await gsoeToken.deployed();
    });

    it("Should set deployer as admin and minter", async function () {
        const DEFAULT_ADMIN_ROLE = await gsoeToken.DEFAULT_ADMIN_ROLE();
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();

        expect(await gsoeToken.hasRole(DEFAULT_ADMIN_ROLE, deployer.address)).to.be.true;
        expect(await gsoeToken.hasRole(MINTER_ROLE, deployer.address)).to.be.true;
    });

    it("Should have initial mintFee and feeRecipient set correctly", async function () {
        const mintFee = await gsoeToken.mintFee();
        const feeRecipient = await gsoeToken.feeRecipient();

        expect(mintFee).to.equal(ethers.utils.parseEther("0.01"));
        expect(feeRecipient).to.equal(deployer.address);
    });

    it("Should revert if caller does not have MINTER_ROLE", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();

        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                10,
                { value: ethers.utils.parseEther("0.01") }
            )
        ).to.be.revertedWithCustomError(gsoeToken, "AccessControlUnauthorizedAccount")
            .withArgs(addr1.address, MINTER_ROLE);

    });

    it("Should revert if quantity is zero", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();

        // Grant MINTER_ROLE to addr1 to isolate this test from permission errors
        await gsoeToken.connect(deployer).grantRole(MINTER_ROLE, addr1.address);

        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                0, // quantity zero triggers revert
                10,
                { value: 0 }
            )
        ).to.be.revertedWith("Quantity must be at least 1");
    });

    it("Should revert if royaltyPercentage > 100", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.connect(deployer).grantRole(MINTER_ROLE, addr1.address);

        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                101, // invalid royalty > 100
                { value: ethers.utils.parseEther("0.01") }
            )
        ).to.be.revertedWith("Royalty too high");
    });

    it("Should revert if incorrect mint fee paid", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.connect(deployer).grantRole(MINTER_ROLE, addr1.address);

        // mintFee is 0.01 ether, send less to trigger revert
        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                10,
                { value: ethers.utils.parseEther("0.005") } // less than required
            )
        ).to.be.revertedWith("Incorrect minting fee");

        // also test sending more than required
        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                10,
                { value: ethers.utils.parseEther("0.02") } // more than required
            )
        ).to.be.revertedWith("Incorrect minting fee");
    });

    it("Should revert if incorrect mint fee paid", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.connect(deployer).grantRole(MINTER_ROLE, addr1.address);

        // mintFee is 0.01 ether per token, quantity 1 means 0.01 ether required

        // Sending less than required fee (0.005 ether)
        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                10,
                { value: ethers.utils.parseEther("0.005") }
            )
        ).to.be.revertedWith("Incorrect minting fee");

        // Sending more than required fee (0.02 ether)
        await expect(
            gsoeToken.connect(addr1).mintBatch(
                addr1.address,
                addr1.address,
                "ipfs://tokenURI",
                1,
                10,
                { value: ethers.utils.parseEther("0.02") }
            )
        ).to.be.revertedWith("Incorrect minting fee");
    });

    it("Should successfully mint a batch", async function () {
        const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
        await gsoeToken.connect(deployer).grantRole(MINTER_ROLE, addr1.address);

        const quantity = 3;
        const royaltyPercentage = 15;
        const tokenURI = "ipfs://tokenURI";

        // Track feeRecipient balance before minting
        const feeRecipient = await gsoeToken.feeRecipient();
        const feeRecipientBalanceBefore = await ethers.provider.getBalance(feeRecipient);

        // Mint batch from addr1 (who has MINTER_ROLE now)
        const tx = await gsoeToken.connect(addr1).mintBatch(
            addr1.address,
            addr1.address,
            tokenURI,
            quantity,
            royaltyPercentage,
            { value: ethers.utils.parseEther("0.01").mul(quantity) }
        );

        const receipt = await tx.wait();

        // Check event emitted with correct args
        const batchNumber = 1; // this is the first batch in a fresh deploy
        const event = receipt.events.find(e => e.event === "BatchMinted");
        expect(event).to.not.be.undefined;

        const [emittedBatchNumber, emittedCreator, emittedTokenIds, emittedRoyalty, emittedTo, emittedCreatedAt] = event.args;
        expect(emittedBatchNumber).to.equal(batchNumber);
        expect(emittedCreator).to.equal(addr1.address);
        expect(emittedRoyalty).to.equal(royaltyPercentage);
        expect(emittedTo).to.equal(addr1.address);
        expect(emittedTokenIds.length).to.equal(quantity);
        expect(emittedCreatedAt.toNumber()).to.be.greaterThan(0);

        // Check ownership and metadata for each minted token
        for (let i = 0; i < quantity; i++) {
            const tokenId = emittedTokenIds[i];

            expect(await gsoeToken.ownerOf(tokenId)).to.equal(addr1.address);

            const meta = await gsoeToken.getTokenMetadata(tokenId);
            expect(meta.batchNumber).to.equal(batchNumber);
            expect(meta.batchSpecificId).to.equal(i + 1);
            expect(meta.royaltyPercentage).to.equal(royaltyPercentage);
            expect(meta.creator).to.equal(addr1.address);
            expect(meta.createdAt).to.equal(await gsoeToken.createdAtOf(tokenId)); // sanity check

            // Check token URI set properly
            expect(await gsoeToken.tokenURI(tokenId)).to.equal(tokenURI);
        }

        // Check batchNumber incremented after minting
        expect(await gsoeToken.currentBatchNumber()).to.equal(batchNumber + 1);

        // Check mint fee was transferred to feeRecipient
        const feeRecipientBalanceAfter = await ethers.provider.getBalance(feeRecipient);
        const expectedFee = ethers.utils.parseEther("0.01").mul(quantity);
        expect(feeRecipientBalanceAfter.sub(feeRecipientBalanceBefore)).to.equal(expectedFee);
    });
});
