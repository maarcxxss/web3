# ERC-20 Token Implementation

A custom ERC-20 token implemented in Solidity using Foundry. This project is part of my personal work on Ethereum smart contracts, with a focus on understanding token standards, access control and on-chain permissions.

## Overview

`MyToken` implements the core ERC-20 interface and extends it with additional functionality for supply management, role-based permissions, pausing and signature-based approvals.

The project is intended as a practical exercise in smart contract development. The implementation is built around the standard ERC-20 interface while keeping the additional features explicit and easy to inspect.

## Features

* **ERC-20 functionality:** token metadata, balances, transfers, allowances and approvals.
* **Supply cap:** a maximum token supply of 2,000 MTK.
* **Minting and burning:** controlled token creation and token destruction.
* **Access control:** owner and minter roles with separate permissions.
* **Pause mechanism:** the owner can pause and resume the token operations covered by the pause checks.
* **Permit:** signature-based approvals using EIP-712 and the EIP-2612 approach.
* **Custom errors and events:** explicit error handling and events for relevant state changes.

## Technical details

* Token name: `My Token`
* Symbol: `MTK`
* Decimals: `18`
* Maximum supply: `2,000 MTK`
* Language: Solidity
* Development framework: Foundry

The constructor accepts the initial supply as a whole-token amount. Other token operations use the smallest token units, following the usual ERC-20 convention.

The owner and minter roles are independent after deployment. The owner manages permissions and the pause mechanism, while authorised minters can create tokens within the supply cap.

## Tech stack

* Solidity
* Foundry (`forge`)
* Git and GitHub

## Project structure

```text
erc20/
├── src/
│   ├── IERC20.sol
│   └── MyToken.sol
├── test/
├── foundry.toml
└── README.md
```

## Getting started

Make sure Foundry is installed and available in your terminal.

From this directory, compile the contracts with:

```bash
forge build
```

To run the test suite once it has been added, use:

```bash
forge test
```

## Project status

The initial token implementation is in place and compiles successfully. The test suite and final project documentation are still in progress.

## Next steps

* Add tests for the ERC-20 functions and token supply limits.
* Test access control, pause behaviour and edge cases.
* Verify the permit flow, including invalid signatures, expired deadlines and nonce handling.
* Document the test results and deployment workflow.
