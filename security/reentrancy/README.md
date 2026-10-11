# Reentrancy

An educational laboratory demonstrating a reentrancy vulnerability in Solidity and how the Checks-Effects-Interactions (CEI) pattern can mitigate it.

The lab includes a deliberately vulnerable staking contract, a protected implementation, a malicious ERC-20-like token, and an attacker contract. Foundry tests reproduce the attack locally and verify the behavior of both implementations.

> **Disclaimer:** This repository is intended for educational purposes. The vulnerable contract and malicious token must not be used in production.

## Objectives

- Understand how reentrancy works in Solidity.
- Identify the risks of making external calls before updating contract state.
- Reproduce a reentrancy attack using a malicious callback.
- Compare vulnerable and protected implementations.
- Apply the Checks-Effects-Interactions (CEI) pattern.
- Verify the expected behavior with Foundry tests.

## Lab structure

```text
security/
└── reentrancy/
    ├── README.md
    └── staking/
        ├── README.md
        ├── analysis.md
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

## How the attack works

The vulnerable staking contract transfers tokens before clearing the caller's recorded balance.

During the external token transfer, the malicious token calls the recipient's `onTokenReceived()` callback. The attacker uses this callback to re-enter `withdrawAll()` before the original withdrawal has updated the staking balance.

As a result, the attacker can withdraw more tokens than its recorded deposit.

The protected contract reverses this order: it clears the recorded balance before transferring tokens. When the attacker attempts to re-enter, the second withdrawal fails because the recorded balance is already zero.

## Implementation comparison

| Contract | Purpose |
|---|---|
| `VulnerableStaking.sol` | Demonstrates the reentrancy vulnerability. |
| `SecureStaking.sol` | Applies CEI to prevent the demonstrated attack. |
| `ReentrantToken.sol` | Introduces an intentional callback during token transfers. |
| `ReentrancyAttacker.sol` | Deposits tokens and attempts a reentrant withdrawal. |
| `Reentrancy.t.sol` | Tests initialization, successful exploitation, and mitigation. |

## Run the lab

Navigate to the `staking/` directory and execute:

```bash
forge test -vv
```

The tests verify that the attack succeeds against `VulnerableStaking` and that the transaction reverts against `SecureStaking`.

## Documentation

- [Staking lab — setup and execution](staking/README.md)
- [Technical analysis — attack flow and mitigation](staking/analysis.md)

## Scope and limitations

The lab demonstrates one specific reentrancy scenario. The callback is intentionally implemented in a custom token; it does not represent the behavior of every standard ERC-20 token.

Applying CEI to the tested withdrawal path does not constitute a complete security audit. Other external calls, validation rules, and potential attack surfaces must be reviewed separately.
