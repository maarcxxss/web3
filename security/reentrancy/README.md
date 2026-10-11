# Reentrancy

**Reentrancy** is a smart contract security vulnerability that occurs when an external call allows control flow to re-enter a contract before a previous operation has completed its execution and updated its state consistently.

This behavior can lead to unexpected state changes, broken invariants, and, in certain scenarios, the unauthorized withdrawal or manipulation of assets.

Reentrancy is not limited to a specific type of protocol. It can affect different smart contract architectures, including staking systems, lending protocols, token vaults, exchanges, and other systems that interact with external contracts.

This section explores reentrancy vulnerabilities through practical Solidity and Foundry experiments, focusing on how attacks work, how to reproduce them, and how to evaluate potential mitigations.

---

## Objectives

The purpose of this section is to develop a practical understanding of reentrancy vulnerabilities and their impact on smart contract security.

The main objectives are to:

- Understand how reentrancy works during EVM execution.
- Identify vulnerable patterns involving external calls.
- Analyze how state inconsistencies can be exploited.
- Reproduce vulnerabilities using Solidity and Foundry.
- Compare vulnerable and secure implementations.
- Apply defensive patterns and evaluate their limitations.
- Develop automated tests that verify security properties.

---

## Reentrancy variants

Reentrancy can occur in different forms depending on the contract architecture, the functions involved, and the state shared between contracts.

The main scenarios explored in this section may include:

- **Single-function reentrancy:** re-entering the same function before its previous execution has completed.
- **Cross-function reentrancy:** exploiting interactions between multiple functions that depend on shared state.
- **Cross-contract reentrancy:** exploiting interactions between different contracts whose operations affect one another.
- **Read-only reentrancy:** exploiting intermediate or inconsistent state observed during execution to influence other protocol operations.

These categories are not mutually exclusive. A single vulnerability may involve several of these mechanisms.

---

## Common causes

Reentrancy vulnerabilities often arise when a contract makes an external call before completing the state updates required to preserve its invariants.

A simplified vulnerable pattern is:

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];

    // External interaction occurs first.
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");

    // State is updated too late.
    balances[msg.sender] = 0;
}
```

If the recipient is a contract capable of calling back into `withdraw()`, the function may execute again while the original recorded balance is still available.

The exact impact depends on the contract's logic, the external interaction, and the invariants that should be preserved.

---

## Defensive techniques

The experiments in this section will examine several techniques for reducing reentrancy risk.

### Checks-Effects-Interactions (CEI)

Perform validation first, update the contract's state second, and make external calls afterward.

### Reentrancy guards

Use mechanisms such as a reentrancy lock to prevent protected functions from being entered recursively.

### Careful external-call handling

Review calls to external contracts, including token transfers, callbacks, and interactions with other protocols.

### Invariant-based testing

Define the conditions that must always hold and verify them through automated tests, including adversarial scenarios.

No individual technique guarantees security in every situation. The appropriate mitigation depends on the complete contract architecture and its interactions.

---

## Practical laboratories

Each laboratory focuses on a particular reentrancy scenario and contains its own implementation, tests, and technical analysis.

| Laboratory | Description |
|---|---|
| [Staking Reentrancy](staking/) | Exploiting a vulnerable withdrawal operation and comparing it with a CEI-based implementation. |

Additional laboratories will be added as new scenarios are studied.

---

## Testing environment

The laboratories use **Solidity** and **Foundry** to deploy contracts, reproduce attacks, and verify their effects through automated tests.

Run the tests from the relevant laboratory directory:

```bash
forge test -vv
```

For a more detailed execution trace:

```bash
forge test -vvvv
```

Each laboratory provides its own instructions and expected results.

---

## Scope and limitations

These laboratories are educational experiments designed to study specific vulnerability patterns and defensive techniques.

Passing the tests demonstrates that the tested scenarios behave as expected. It does not constitute a complete security audit or guarantee that a contract is secure against all possible attacks.

The objective is to understand not only how a vulnerability can be exploited, but also why it exists, how a mitigation works, and what risks may remain.
