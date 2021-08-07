// import "@nomiclabs/hardhat-etherscan";
require('@nomiclabs/hardhat-etherscan')
// import "@nomiclabs/hardhat-waffle";
require('@nomiclabs/hardhat-waffle')
// import "hardhat-gas-reporter";
require('hardhat-gas-reporter')
// import "solidity-coverage";
require('solidity-coverage')

// import { resolve } from "path";
const { resolve } = require('path')

// import { config as dotenvConfig } from "dotenv";
const { config: conf } = require('dotenv')
const dotenvConfig = conf

dotenvConfig({ path: resolve(__dirname, './.env') })

const chainIds = {
  bsc: 56,
  kcc: 321,
  polygon: 137,
  ganache: 1337,
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
}

// Ensure that we have all the environment variables we need.
const privateKey = process.env.PRIVATE_KEY
if (!privateKey) {
  throw new Error('Please set your PRIVATE_KEY in a .env file')
}
// const mnemonic = process.env.MNEMONIC;
// if (!mnemonic) {
//   throw new Error("Please set your MNEMONIC in a .env file");
// }

const infuraApiKey = process.env.INFURA_API_KEY
if (!infuraApiKey) {
  throw new Error('Please set your INFURA_API_KEY in a .env file')
}

function createConfig(network, rpcUrl = null) {
  const url = rpcUrl || `https://${network}.infura.io/v3/${infuraApiKey}`
  return {
    accounts: [privateKey],
    // accounts: {
    //   count: 10,
    //   initialIndex: 0,
    //   mnemonic,
    //   path: "m/44'/60'/0'/0",
    // },
    chainId: chainIds[network] || 1,
    url,
  }
}

const config = {
  defaultNetwork: 'hardhat',
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
    // apiKey: process.env.BSCSCAN_API_KEY,
    // apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  gasReporter: {
    currency: 'USD',
    enabled: process.env.REPORT_GAS ? true : false,
    excludeContracts: [],
    src: './contracts',
  },
  networks: {
    hardhat: {
      accounts: {
        // mnemonic,
        accounts: [privateKey],
      },
      chainId: chainIds.hardhat,
    },
    bsc: createConfig('bsc', 'https://bsc-dataseed.binance.org'),
    kcc: createConfig('kcc', 'https://rpc-mainnet.kcc.network'),
    polygon: createConfig(
      'polygon',
      'https://matic-mainnet.chainstacklabs.com'
    ),
    mainnet: createConfig('mainnet'),
    goerli: createConfig('goerli'),
    kovan: createConfig('kovan'),
    rinkeby: createConfig('rinkeby'),
    ropsten: createConfig('ropsten'),
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },
  solidity: {
    version: '0.8.4',
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: 'none',
      },
      // You should disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
  },
}

// export default config;
module.exports.default = config
