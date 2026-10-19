# ERC-20 Token — Solidity & Foundry

A custom ERC-20 token implementation with capped supply, access control, pausing, minting, burning, and signature-based approvals. This project is part of a personal Blockchain and Web3 learning portfolio.

> **Quick to try:** clone the repository, install Foundry, and run the tests with the commands below.

## Quick start

Prerequisites: [Git](https://git-scm.com/) and [Foundry](https://book.getfoundry.sh/getting-started/installation).

Run from a terminal in a fresh clone:

```bash
git clone https://github.com/maarcxxss/web3.git
cd web3/standards/erc20
forge install foundry-rs/forge-std --no-commit
forge build
forge test
```

Foundry installs `forge-std` locally under `lib/`; the dependency is ignored by Git. The commands above compile the project and run its unit, fuzz, and invariant tests.

To deploy and interact with the token on a local chain, continue to [Local deployment](#local-deployment).

## Overview

`MyToken.sol` is a custom implementation of the core ERC-20 interface in `IERC20.sol`. The token uses 18 decimals and has a maximum supply of 2,000 tokens. The deployer starts as owner and minter.

The implementation also includes a custom `permit` function based on EIP-2612 and EIP-712. It allows an account to set an ERC-20 allowance with a signature instead of an on-chain `approve` transaction.

## Features

- **ERC-20 transfers:** `transfer`, `approve`, `transferFrom`, `balanceOf`, `allowance`, and `totalSupply`.
- **Supply management:** owner-authorized minting, token burning, and a fixed supply cap.
- **Access control:** ownership and minter permissions.
- **Pausing:** the owner can pause and resume token transfers and supply changes.
- **Permit:** signature-based approvals with EIP-712 domain separation and nonce protection.
- **Custom errors and events:** explicit failure conditions and observable contract updates.

## Project structure

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
└── README.md
```

## Tests and coverage

The test files are organized by testing approach:

| Suite | Scope |
|---|---|
| `MyToken.t.sol` | Unit tests for ERC-20 behavior, access control, minting, burning, pausing, events, custom errors, and `permit`. |
| `MyToken_fuzz.t.sol` | Fuzz tests for generated transfer, allowance, mint, and burn amounts. |
| `MyToken_invariant.t.sol` | Invariants for total supply and the sum of balances across the test accounts. |

Run an individual suite from `standards/erc20/`:

```bash
forge test --match-path test/MyToken.t.sol
forge test --match-path test/MyToken_fuzz.t.sol
forge test --match-path test/MyToken_invariant.t.sol
```

Generate a coverage report:

```bash
forge coverage --report summary
```

The latest results recorded for this project are **81 tests passed**, with **100%** line, instruction, branch, and function coverage. Invariant checks cover the actions and accounts configured in their handler; these results are not a formal proof or a security audit.

## Local deployment

The deployment script is intended for a local Anvil node. It uses the default Anvil account, which is for local development only.

1. Start Anvil in a separate terminal:

   ```bash
   anvil
   ```

2. From `standards/erc20/`, deploy the token to the local chain:

   ```bash
   forge script script/DeployMyToken.s.sol:DeployMyToken --rpc-url http://127.0.0.1:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked --broadcast
   ```

3. Copy the deployed address from the output and query the token:

   ```bash
   cast call <TOKEN_ADDRESS> "name()(string)" --rpc-url http://127.0.0.1:8545
   cast call <TOKEN_ADDRESS> "totalSupply()(uint256)" --rpc-url http://127.0.0.1:8545
   ```

Restarting Anvil resets its local chain, so the token must be redeployed. No real funds or external network are needed for this walkthrough.

## Security and scope

This is an educational implementation, not an audited or production-ready token. The tests exercise the documented behaviors, but passing tests and coverage figures do not establish the absence of vulnerabilities. Do not use it to manage real funds.

## Project status

- [x] ERC-20 implementation, custom errors, and events.
- [x] Unit, fuzz, and invariant test suites.
- [x] Foundry deployment script and local Anvil walkthrough.
- [ ] Independent security review.
- [ ] Evaluate deployment to a testnet.

## Author

Personal learning project focused on Blockchain, Solidity, Smart Contracts, and Web3.

GitHub: [@maarcxxss](https://github.com/maarcxxss)
