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
  const contract = await Contract
    .deploy
    /* { maxFeePerGas, maxPriorityFeePerGas } */
    ()

  console.log('Contract address:', contract.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
