import fs from 'fs'
import path from 'path'

// import solc from 'solc'
const solc = require('solc')

export default async function compile(contractFullPath: string) {
  const contractFile = path.basename(contractFullPath)
  const contractSource = await fs.promises.readFile(contractFullPath, 'utf-8')
  const input = {
    language: 'Solidity',
    sources: {
      [contractFile]: {
        content: contractSource,
      },
    },
    settings: {
      outputSelection: {
        '*': {
          '*': ['*'],
        },
      },
    },
  }
  // return solc.compile(JSON.stringify(input)).contracts[`:${contractFile}`]
  return solc.compile(JSON.stringify(input))
}
