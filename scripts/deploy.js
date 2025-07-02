const hre = require("hardhat");

async function deployContracts() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}`);

  // 1. Deploy GSOEToken (ERC721)
  const GSOEToken = await hre.ethers.getContractFactory("GSOEToken");
  const gsoeToken = await GSOEToken.deploy();
  await gsoeToken.deployed();
  console.log(`GSOEToken deployed to: ${gsoeToken.address}`);

  // 2. Deploy MarketplaceCore (or NFTMarketplace core contract) with GSOEToken address
  const MarketplaceCore = await hre.ethers.getContractFactory("MarketplaceCore");
  const marketplaceCore = await MarketplaceCore.deploy(gsoeToken.address);
  await marketplaceCore.deployed();
  console.log(`MarketplaceCore deployed to: ${marketplaceCore.address}`);

  // 3. Deploy MarketplaceView with MarketplaceCore address
  const MarketplaceView = await hre.ethers.getContractFactory("MarketplaceView");
  const marketplaceView = await MarketplaceView.deploy(marketplaceCore.address);
  await marketplaceView.deployed();
  console.log(`MarketplaceView deployed to: ${marketplaceView.address}`);

  // 4. Deploy any other contract if needed (e.g., NFTMarketMinter)
  const NFTMarketMinter = await hre.ethers.getContractFactory("NFTMarketMinter");
  const nftMarketMinter = await NFTMarketMinter.deploy(marketplaceCore.address);
  await nftMarketMinter.deployed();
  console.log(`NFTMarketMinter deployed to: ${nftMarketMinter.address}`);

  // 5. Grant MINTER_ROLE (or any roles) to marketplaceCore or other contracts as needed
  const MINTER_ROLE = await gsoeToken.MINTER_ROLE();
  const grantTx = await gsoeToken.grantRole(MINTER_ROLE, marketplaceCore.address);
  await grantTx.wait();
  console.log(`Granted MINTER_ROLE to MarketplaceCore`);

  // If MarketplaceView or others need roles or initial setup, do it here too
}

deployContracts()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
