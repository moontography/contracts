async function main() {
  const [deployer] = await ethers.getSigners()

  console.log('Deploying contracts with the account:', deployer.address)

  console.log('Account balance:', (await deployer.getBalance()).toString())

  // const maxFeePerGas = ethers.utils.parseUnits('80', 'gwei')
  // const maxPriorityFeePerGas = ethers.utils.parseUnits('2', 'gwei')

  const Contract = await ethers.getContractFactory(process.env.CONTRACT_NAME)
  // contract constructor arguments can be passed as parameters in #deploy
  // await Contract.deploy(arg1, arg2, ...)
  // TODO: make configurable through CLI params
  // const maxFeePerGas = ethers.utils.parseUnits('80', 'gwei')
  // const maxPriorityFeePerGas = ethers.utils.parseUnits('2', 'gwei')
  const contract = await Contract.deploy(
    /* { maxFeePerGas, maxPriorityFeePerGas } */
    '0x5f67df361f568e185aA0304A57bdE4b8028d059E',
    '0x4AED49E5EB646b3298b05737Df86e69FC844e35C',
    '0x8a753747a1fa494ec906ce90e9f37563a8af630e',
    '6450'
  )

  console.log('Contract address:', contract.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
