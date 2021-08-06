# Moontography Contracts

## Compile

```sh
$ npx hardhat compile
```

## Deploy

If your contract requires extra constructor arguments, you'll have to specify them in (deploy options)[https://hardhat.org/plugins/hardhat-deploy.html#deployments-deploy-name-options]

```sh
$ CONTRACT_NAME=MTGY npx hardhat run --network rinkeby scripts/deploy.js
```

## Verify

```sh
$ npx hardhat verify CONTRACT_ADDRESS --network rinkeby
```
