# ERC-20 Token — Solidity & Foundry

A custom implementation of a fungible token compatible with the **ERC-20 Ethereum standard**, developed in Solidity as part of a personal Blockchain and Web3 learning project.

This project explores smart contract fundamentals, the implementation of the main mechanisms of a token, and the verification of its behavior through automated testing with Foundry.

**Status:** Implementation and testing completed for the current version. Security review and technical documentation are still in progress.

## Features

- **ERC-20:** Custom implementation of the standard's core functions.
- **Balances and supply:** Balance and total supply queries.
- **Transfers:** `transfer`, `approve`, and `transferFrom`.
- **Events:** `Transfer`, `Approval`, and events related to contract management.
- **Access control:** Contract ownership and minter permissions.
- **Mint and burn:** Token creation and destruction.
- **Supply cap:** Maximum issuance limit enforced through `CAP`.
- **Pausability:** `pause` and `unpause` functions.
- **Permit:** Custom implementation based on EIP-2612 and EIP-712 for setting allowances through signatures.
- **Custom errors:** Specific errors representing failure conditions.
- **Testing:** Unit tests, fuzz testing, and invariant testing.
- **Code coverage:** Coverage analysis using Foundry.

## Technologies

- Solidity
- Foundry: Forge, Anvil, and Cast
- Git and GitHub
- Visual Studio Code

## Project Structure

```text
erc20/
├── src/
│   ├── IERC20.sol
│   └── MyToken.sol
├── test/
│   ├── MyToken.t.sol
│   ├── MyToken_fuzz.t.sol
│   └── MyToken_invariant.t.sol
├── script/
│   └── DeployMyToken.s.sol
├── foundry.toml
├── .gitignore
└── README.md
```

### Contracts

- `IERC20.sol`: Defines the ERC-20 interface used by the project.
- `MyToken.sol`: Contains the custom token implementation.

### Tests

- `MyToken.t.sol`: Unit tests covering functions, permissions, events, errors, and contract mechanisms.
- `MyToken_fuzz.t.sol`: Tests using automatically generated inputs.
- `MyToken_invariant.t.sol`: Invariant tests that verify properties across sequences of token transfers.

### Scripts

- `DeployMyToken.s.sol`: Deploys the token using Foundry.

## Installation and Execution

**Prerequisites:** Git and Foundry installed.

### 1. Clone the repository

```bash
git clone https://github.com/maarcxxss/web3.git
cd web3/standards/erc20
```

### 2. Install the testing dependency

The project uses `forge-std` for Foundry tests and deployment scripts.

```bash
forge install foundry-rs/forge-std --no-commit
```

### 3. Compile the contracts

```bash
forge build
```

### 4. Run all tests

```bash
forge test
```

### 5. Run unit tests

```bash
forge test --match-path test/MyToken.t.sol
```

### 6. Run fuzz tests

```bash
forge test --match-path test/MyToken_fuzz.t.sol
```

### 7. Run invariant tests

```bash
forge test --match-path test/MyToken_invariant.t.sol
```

### 8. Generate a coverage report

```bash
forge coverage --report summary
```

## Local Deployment with Anvil

Anvil runs a local Ethereum blockchain that allows contracts to be deployed and transactions to be tested without using real funds.

### 1. Start Anvil

In a separate terminal, run:

```bash
anvil
```

Keep this terminal open while interacting with the local blockchain.

### 2. Deploy the token

From the `standards/erc20` directory, run:

```bash
forge script script/DeployMyToken.s.sol:DeployMyToken --rpc-url http://127.0.0.1:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked --broadcast
```

This command uses a default Anvil account. Verify that the specified address appears among the accounts provided by your local Anvil instance.

Once deployment completes, Foundry will display the deployed contract address. Use that address in the following queries.

### 3. Query the token

Replace `CONTRACT_ADDRESS` with the address returned by the deployment command.

Query the token name:

```bash
cast call CONTRACT_ADDRESS "name()(string)" --rpc-url http://127.0.0.1:8545
```

Query the total supply:

```bash
cast call CONTRACT_ADDRESS "totalSupply()(uint256)" --rpc-url http://127.0.0.1:8545
```

Query the number of decimals:

```bash
cast call CONTRACT_ADDRESS "decimals()(uint8)" --rpc-url http://127.0.0.1:8545
```

Query an account's balance:

```bash
cast call CONTRACT_ADDRESS "balanceOf(address)(uint256)" ACCOUNT_ADDRESS --rpc-url http://127.0.0.1:8545
```

### 4. Send a token transfer

Example: transfer 10 tokens between two Anvil accounts.

```bash
cast send CONTRACT_ADDRESS "transfer(address,uint256)" RECIPIENT_ADDRESS 10000000000000000000 --rpc-url http://127.0.0.1:8545 --unlocked --from SENDER_ADDRESS
```

With 18 decimals, `10000000000000000000` represents 10 tokens.

The command returns transaction information, including its hash, block, gas usage, and generated logs.

**Note:** Contract addresses and balances belong to the local Anvil instance. Restarting Anvil may erase the local blockchain state, requiring the contract to be deployed again.

## Testing and Coverage

The project uses three complementary approaches to verify the contract's behavior.

### Unit Tests

These tests check individual operations, including transfers, allowances, access control, token minting and burning, pausing, events, custom errors, and `permit` signatures.

**Result:** 72 unit tests passed.

### Fuzz Testing

Fuzz testing uses automatically generated inputs to explore different values and verify expected properties.

Eight fuzz tests have been implemented, with 256 cases per test in the current configuration.

**Result:** 8 fuzz tests passed.

### Invariant Testing

Invariant testing verifies properties that must remain true across sequences of operations generated by Foundry.

Two invariants are checked:

- `invariant_TotalSupplyEqualsBalances`: the total supply equals the sum of the balances of the accounts included in the test environment.
- `invariant_TotalSupplyRemainsConstant`: the total supply remains constant during token transfers.

The current configuration executes 256 sequences (*runs*) with 128,000 handler calls, with no reverts or discarded cases.

These invariants apply to the operations and accounts defined in the current test setup. They do not constitute an exhaustive verification of every contract feature.

### Coverage Results

Results obtained using `forge coverage --report summary`:

| Metric | Coverage |
|---|---:|
| Lines | 100% |
| Instructions | 100% |
| Branches | 100% |
| Functions | 100% |

The recorded summary from the full `forge test` execution reports **81 tests passed, 0 failed, and 0 skipped**.

Coverage measures which parts of the code are exercised by tests. It does not, by itself, guarantee the absence of bugs or vulnerabilities. Security analysis remains an important part of the development process.

## Roadmap

- [x] Custom ERC-20 contract implementation.
- [x] Balance, allowance, and transfer management.
- [x] Access control and minter permissions.
- [x] Mint and burn functions.
- [x] Maximum supply limit.
- [x] Pausing mechanism.
- [x] `permit` implementation.
- [x] Unit tests.
- [x] Fuzz testing.
- [x] Invariant testing.
- [x] 100% coverage across the measured metrics.
- [x] Foundry deployment script.
- [x] Local deployment and manual checks using Anvil.

## Future Improvements

- [ ] Review edge cases and potential vulnerabilities.
- [ ] Conduct a more comprehensive security review.
- [ ] Expand the technical documentation and interaction examples.
- [ ] Evaluate deployment to a testnet.

## Project Goal

This project aims to understand Ethereum standards and apply good practices in smart contract development, testing, and security.

It has been developed incrementally, prioritizing an understanding of the contract's logic, behavioral verification, and reproducibility of experiments.

This is an educational project and **is not currently intended to manage real funds**.

## Author

Personal Computer Science and Engineering project focused on Blockchain, Solidity, Smart Contracts, and Web3 development.

GitHub: [@maarcxxss](https://github.com/maarcxxss)