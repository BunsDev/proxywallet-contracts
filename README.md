# Solidity Template V2

## Prerequisites 

1. Install dependencies:

    ```shell
    npm ci
    ```

1. Create `.env` file based on `.env.example`:

    ```shell
    INFURA_KEY="<string?>"
    MNEMONIC_DEV="<string?>"
    MNEMONIC_PROD="<string?>"
    FORKING_NETWORK="<main | sepolia?>"
    ETHERSCAN_API_KEY="<string?>"
    ```

1. Compile contracts:

    ```shell
    npm run compile
    ```

## Development

### Run tests

```shell
npm run test
```

### Coverage report

```shell
npm run coverage
```

### Deploy contracts

```shell
npm run deploy ./ignition/modules/lock.ts -- --parameters ./ignition/parameters.json --network <network-name>
```

### Run code analyzers

```shell
npm run codestyle
```
