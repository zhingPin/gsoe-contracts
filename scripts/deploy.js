const hre = require("hardhat");

async function deployContracts() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying contracts with account: ${deployer.address}`);


  // 1. Deploy GSOEToken (ERC721)
  const GSOEToken = await hre.ethers.getContractFactory("GSOEToken");
  const gsoeToken = await GSOEToken.deploy();
  await gsoeToken.deployed();
  console.log(`GSOEToken deployed to: ${gsoeToken.address}`);

  // 2. Deploy NFTMarketplace with the address of GSOEToken
  const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
  const nftMarketplace = await NFTMarketplace.deploy(gsoeToken.address);
  await nftMarketplace.deployed();
  console.log(`NFTMarketplace deployed to: ${nftMarketplace.address}`);

  // 3. Grant MINTER_ROLE to the marketplace contract
  const MINTER_ROLE = await gsoeToken.MINTER_ROLE(); // bytes32 hash
  const grantTx = await gsoeToken.grantRole(MINTER_ROLE, nftMarketplace.address);
  await grantTx.wait();
  console.log(`Granted MINTER_ROLE to NFTMarketplace`);

}


deployContracts()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
