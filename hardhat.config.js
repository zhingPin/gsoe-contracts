require("@nomicfoundation/hardhat-toolbox");
require("solidity-coverage");

require("dotenv").config();

const { TEST_PRIVATE_KEY, LIVE_PRIVATE_KEY, POLYGON_AMOY_RPC } = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true, runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 80001
    },
    polygon_amoy: {
      url: POLYGON_AMOY_RPC,
      accounts: [`0x${TEST_PRIVATE_KEY}`],
    },

  },
  // etherscan: {
  //   apiKey: {
  //     polygonAmoy: POLYGONSCAN_API_KEY || "",
  //   },
  // },
  contractSizer: {
    runOnCompile: true,
  },
};
