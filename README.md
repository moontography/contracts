# ok.let's.go. Contracts

## Compile

```sh
$ npx hardhat compile
```

## Deploy

If your contract requires extra constructor arguments, you'll have to specify them in [deploy options](https://hardhat.org/plugins/hardhat-deploy.html#deployments-deploy-name-options).

```sh
$ CONTRACT_NAME=OKLG npx hardhat run --network rinkeby scripts/deploy.js
```

## Verify

```sh
$ npx hardhat verify CONTRACT_ADDRESS --network rinkeby
```

## Flatten

You generally should not need to do this simply to verify in today's compiler version (0.8.x), but should you ever want to:

```sh
$ npx hardhat flatten {contract file location} > output.sol
```
