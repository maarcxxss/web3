# Token Staking — Solidity & Foundry

A fixed-duration ERC-20 staking and reward-distribution contract with unit, fuzz, and invariant tests. This project is part of a personal Blockchain and Web3 learning portfolio.

> **Quick to try:** clone the repository, install Foundry, and run the tests with the commands below.

## Quick start

Prerequisites: [Git](https://git-scm.com/) and [Foundry](https://book.getfoundry.sh/getting-started/installation).

Run from a terminal in a fresh clone:

```bash
git clone https://github.com/maarcxxss/web3.git
cd web3/defi/staking
forge install foundry-rs/forge-std --no-commit
forge build
forge test
```

Foundry installs `forge-std` locally under `lib/`; the dependency is ignored by Git. The commands above compile the project and run its unit, fuzz, and invariant tests.

To deploy the demo, accrue a reward, and claim it on a local chain, continue to [Local deployment](#local-deployment).

## Overview

`Staking.sol` lets users deposit an ERC-20 token and earn rewards over time. The staking token and reward token may be different contracts. Users approve the staking contract before depositing; they can later withdraw their principal and claim earned rewards.

The owner funds each reward period. A period lasts seven days, and rewards are distributed in proportion to users' stake and the time they participate. The contract tracks unpaid and scheduled rewards in `reservedRewards`.

The local deployment script deploys two instances of the verified `MyToken` contract from `standards/erc20`, deploys `Staking`, deposits an initial stake, and funds the first reward period so the contract can be explored immediately.

## Features

- **Stake and withdraw:** per-user balances and system-wide `totalStaked` accounting.
- **Reward distribution:** per-token reward accumulator and per-user checkpoints preserve earned rewards when stake changes.
- **Owner-funded periods:** a new seven-day period can be funded after the previous one has ended.
- **Token compatibility checks:** fee-on-transfer tokens are rejected because the contract requires the exact amount to arrive.
- **Safety checks:** custom errors describe invalid inputs and failed transfers; state-changing token interactions use a reentrancy guard.

## Project structure

```text
staking/
├── src/
│   ├── IERC20.sol
│   ├── IStaking.sol
│   ├── MyToken.sol
│   └── Staking.sol
├── test/
│   ├── Staking.t.sol
│   ├── StakingFuzz.t.sol
│   ├── StakingInvariant.t.sol
│   └── mocks/
│       ├── CoverageERC20.sol
│       └── FeeToken.sol
├── script/
│   └── DeployStaking.s.sol
├── foundry.toml
└── README.md
```

`IStaking.sol` defines the public contract API and events for integrations such as a web application; `Staking.sol` implements that interface and declares its custom errors. The `MyToken.sol` and `IERC20.sol` files in `src/` are copied from `standards/erc20/src/` so this example deploys the same ERC-20 implementation. `CoverageERC20.sol` and `FeeToken.sol` remain under `test/mocks/` because they model special token behavior used only by tests.

## Tests and coverage

The test files are organized by testing approach:

| Suite | Scope |
|---|---|
| `Staking.t.sol` | Unit tests for deployment, staking, withdrawals, reward funding and claims, accounting, custom errors, events, fee-on-transfer rejection, and reentrancy protection. |
| `StakingFuzz.t.sol` | Fuzz tests for bounded deposit and withdrawal amounts, two-user accounting, reward proportions, and scheduled funding. |
| `StakingInvariant.t.sol` | Invariants for principal accounting and reward reserve backing across generated sequences of handler actions. The handler models two users. |

Run an individual suite from `defi/staking/`:

```bash
forge test --match-path test/Staking.t.sol
forge test --match-path test/StakingFuzz.t.sol
forge test --match-path test/StakingInvariant.t.sol
```

Generate a coverage report:

```bash
forge coverage --match-path 'test/Staking*.t.sol' --report summary
```

The latest local run recorded **49 tests passed**: 44 unit tests, 4 fuzz tests with 256 cases each, and 2 invariant properties. The invariant campaign used 10 sequences of 30 actions (300 handler calls, no reverts). These tests cover the configured scenarios and state space; they are not a formal proof or a security audit.

## Local deployment

The walkthrough uses [Anvil](https://book.getfoundry.sh/anvil/) and its default local account. It requires no external network or real funds. The single deployment script creates the staking token, reward token, staking contract, initial stake, and reward funding. Each `MyToken` starts with 1,000 tokens; the script stakes 100 and funds 700.

1. Start Anvil in a terminal and leave it running:

   ```bash
   anvil
   ```

2. In a second terminal, enter `defi/staking/` and deploy both `MyToken` instances, the staking contract, and its initial demo position:

   ```bash
   forge script script/DeployStaking.s.sol:DeployStaking --rpc-url http://127.0.0.1:8545 --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --unlocked --broadcast
   ```

   The script logs the staking contract, both token addresses, and the owner/demo staker address. It also creates a 100-token stake and funds a seven-day reward period with 700 reward tokens.

3. Replace the placeholders with the addresses printed by the script. The owner address is also the default Anvil account shown above.

   ```bash
   cast call STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url http://127.0.0.1:8545
   cast call STAKING_ADDRESS "reservedRewards()(uint256)" --rpc-url http://127.0.0.1:8545
   ```

4. Advance the local chain by one day, mine a block, and inspect the accrued reward:

   ```bash
   cast rpc evm_increaseTime 86400 --rpc-url http://127.0.0.1:8545
   cast rpc evm_mine --rpc-url http://127.0.0.1:8545
   cast call STAKING_ADDRESS "earned(address)(uint256)" OWNER_ADDRESS --rpc-url http://127.0.0.1:8545
   ```

5. Claim the reward from the owner/demo staker account:

   ```bash
   cast send STAKING_ADDRESS "getReward()" --rpc-url http://127.0.0.1:8545 --unlocked --from OWNER_ADDRESS
   ```

The values returned by `cast` are in the token's smallest unit (18 decimals). Restarting Anvil resets its local chain, so rerun the deployment command to start over.

## Security and scope

The contract assumes standard ERC-20 behavior and exact token transfers. Rebasing, fee-on-transfer, or malicious tokens are outside the supported model. The owner controls when reward periods are funded.

This is an educational project, not an audited or production-ready staking system. Do not use it to manage real funds.

## Project status

- [x] Staking and reward-distribution contract.
- [x] Unit, fuzz, and invariant test suites.
- [x] Foundry deployment script using the ERC-20 implementation from `standards/erc20`.
- [ ] Independent security review.
- [ ] Evaluate deployment to a testnet.

## Author

Personal learning project focused on Blockchain, Solidity, Smart Contracts, and Web3.

GitHub: [@maarcxxss](https://github.com/maarcxxss)
