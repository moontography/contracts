import assert from 'assert'
import minimist from 'minimist'
import path from 'path'
import compile from '../compile'

// import solc from 'solc'
const solc = require('solc')

const argv = minimist(process.argv.slice(2))

;(async function compileSmartContract() {
  try {
    const contractFile = argv.c || argv.contract
    assert(contractFile, 'contract file not provided')

    const contract = path.resolve(
      __dirname,
      '..',
      '..',
      'contracts',
      contractFile
    )

    console.log(await compile(contract))
  } catch (err) {
    console.error(`Error compiling contract`, err)
  } finally {
    process.exit()
  }
})()
