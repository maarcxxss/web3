# Reentrancy

La **reentrancy** es una vulnerabilidad de seguridad en Smart Contracts que aparece cuando una llamada externa permite volver a ejecutar una función del contrato antes de que la ejecución anterior haya terminado de actualizar correctamente su estado.

Este comportamiento puede provocar inconsistencias en el estado del contrato y permitir que un atacante aproveche operaciones que no deberían poder ejecutarse repetidamente en esas condiciones.

La reentrancy puede aparecer en distintos contextos, como retiradas de fondos, depósitos, préstamos, intercambios de tokens u otras operaciones que interactúan con contratos externos.

---

## Objectives

The purpose of this section is to study reentrancy vulnerabilities through practical Solidity and Foundry experiments.

The laboratories will explore:

- How reentrancy works at the EVM execution level
- How external calls can enable unexpected control flow
- How vulnerable state-update patterns can be exploited
- How reentrancy can affect different contract architectures
- How to reproduce vulnerabilities using automated tests
- How to apply and evaluate defensive patterns
- What limitations remain after applying a mitigation

---

## Reentrancy variants

Reentrancy is not limited to a single function or contract design. Different scenarios may involve:

- **Single-function reentrancy:** re-entering the same function before its previous execution has completed.
- **Cross-function reentrancy:** exploiting interactions between multiple functions that share or depend on the same state.
- **Cross-contract reentrancy:** exploiting interactions between different contracts whose operations affect one another.
- **Read-only reentrancy:** using intermediate or inconsistent state observed during execution to affect other protocol operations.

These categories can overlap, and the relevant attack surface depends on the contract architecture and its external interactions.

---

## Defensive techniques

The experiments will examine defensive techniques such as:

- Checks-Effects-Interactions (CEI)
- Reentrancy guards
- Careful management of external calls
- State-invariant analysis
- Adversarial testing with malicious contracts

No single technique should be treated as a substitute for reviewing the complete contract and its interactions.

---

## Practical laboratories

| Laboratory | Description |
|---|---|
| [Staking Reentrancy](staking/) | Exploiting a vulnerable withdrawal operation and comparing it with a CEI-based implementation. |

Additional laboratories will be added as new reentrancy scenarios are studied.

---

## Testing environment

The laboratories use Solidity and Foundry to deploy contracts, reproduce attacks and verify their effects through automated tests.

From an individual laboratory directory, tests can be executed with:

```bash
forge test -vv
```

For a more detailed execution trace:

```bash
forge test -vvvv
```

Each laboratory includes its own implementation, tests and technical analysis.

---

## Scope

These laboratories are educational experiments designed to understand specific vulnerability patterns and their mitigations. Passing the tests does not constitute a complete security audit or guarantee that a contract is secure.
