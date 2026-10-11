# Reentrancy — Staking Lab

This Foundry project demonstrates a reentrancy attack against a vulnerable staking contract and compares it with an implementation that follows the Checks-Effects-Interactions (CEI) pattern.

The experiment runs locally and does not require a public blockchain, a wallet, or real funds.

> **Disclaimer:** The vulnerable contract and malicious token are intentionally designed for security testing. Do not use them in production.

## Requirements

- Git
- Foundry (`forge`)
- The `forge-std` testing library included in the project dependencies

## Project structure

```text
staking/
├── foundry.toml
├── src/
│   ├── IERC20.sol
│   ├── IStaking.sol
│   ├── IReentrancyReceiver.sol
│   ├── ReentrantToken.sol
│   ├── VulnerableStaking.sol
│   ├── SecureStaking.sol
│   └── ReentrancyAttacker.sol
└── test/
    └── Reentrancy.t.sol
```

### Contracts and interfaces

| File | Responsibility |
|---|---|
| `IERC20.sol` | Defines the token functions and events used by the lab. |
| `IStaking.sol` | Defines the common staking API. |
| `IReentrancyReceiver.sol` | Defines the callback expected by the malicious token. |
| `ReentrantToken.sol` | Implements token operations and the intentional callback. |
| `VulnerableStaking.sol` | Performs the external transfer before clearing the user's balance. |
| `SecureStaking.sol` | Clears the user's balance before performing the external transfer. |
| `ReentrancyAttacker.sol` | Deposits tokens and attempts to withdraw again through the callback. |

## Run the tests

Open a terminal in this directory and execute:

```bash
forge fmt --check
forge test -vv
```

`forge fmt --check` checks formatting without modifying files.

`forge test -vv` compiles the project as needed and runs the test suite with verbose output.

To inspect more detailed execution traces when investigating a failure, use:

```bash
forge test -vvvv
```

## Test scenarios

### 1. Initialization

`test_SetUp()` verifies the initial token distribution and confirms that the staking contracts and attacker contracts initially hold no tokens.

### 2. Vulnerable implementation

`test_ReentrancyAttack()` prepares the following state:

- The victim deposits 100 tokens.
- The attacker deposits 100 tokens.
- The staking contract holds 200 tokens.
- Both participants have a recorded balance of 100 tokens.

The test enables the malicious callback and starts the attack. The attacker receives 200 tokens even though its recorded deposit was only 100.

The victim's recorded balance remains 100, but the staking contract has no tokens left to cover it.

### 3. Protected implementation

`test_ReentrancyAttackBlocked()` prepares the same initial conditions for `SecureStaking`.

When the attacker attempts to re-enter `withdrawAll()`, the recorded balance is already zero. The second withdrawal reverts with `Nothing to withdraw`.

Because the error propagates through the external call, the complete transaction reverts, including the initial transfer. Both deposits remain in the staking contract, and both recorded balances remain unchanged.

## Expected results

| Test | Expected behavior |
|---|---|
| `test_SetUp` | Passes |
| `test_ReentrancyAttack` | Passes; the vulnerable contract is exploited |
| `test_ReentrancyAttackBlocked` | Passes; the attack transaction reverts |

A passing vulnerability test does not mean the vulnerable contract is secure. It means the test successfully reproduces the expected exploit.

## Security concepts demonstrated

- External calls can transfer control to another contract.
- A callback can re-enter a function before the original call finishes.
- Updating state after an external interaction can leave stale state available during reentrancy.
- Checks-Effects-Interactions updates the relevant state before the external interaction.
- A reverted transaction rolls back its state changes and token transfers.

## Further reading

See [`analysis.md`](analysis.md) for the detailed attack sequence, root cause, mitigation, and limitations.
