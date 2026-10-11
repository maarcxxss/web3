# Reentrancy — Technical Analysis

## 1. Overview

This lab demonstrates a reentrancy vulnerability in a staking contract that transfers tokens before updating the caller's recorded balance.

A malicious recipient can use an external callback to call the withdrawall function again while the original call is still executing.

The vulnerable implementation violates the Checks-Effects-Interactions (CEI) pattern. The protected implementation updates the relevant state before making the external token call.

### Vulnerability summary

| Property | Description |
|---|---|
| Vulnerability | Reentrancy |
| Root cause | External interaction before the relevant state update |
| Affected function | `VulnerableStaking.withdrawAll()` |
| Attacker mechanism | Malicious token callback |
| Mitigation demonstrated | Checks-Effects-Interactions (CEI) |
| Verification | Foundry tests |

## 2. Relevant state

Both staking implementations maintain a mapping of recorded deposits:

```solidity
mapping(address => uint256) public override balances;
```

The mapping records how many tokens each participant is entitled to withdraw according to the staking contract's accounting.

For this experiment, the initial state is:

| Participant | Recorded balance |
|---|---:|
| Victim | 100 tokens |
| Attacker | 100 tokens |
| Total held by staking | 200 tokens |

The victim and attacker have each deposited 100 tokens. The staking contract therefore holds 200 tokens before the attack.

## 3. Root cause

The vulnerable withdrawall function follows this order:

```solidity
uint256 amount = balances[msg.sender];

require(amount > 0, "Nothing to withdraw");

token.transfer(msg.sender, amount);

balances[msg.sender] = 0;
```

The contract reads and validates the recorded balance, transfers the tokens, and only then clears the balance.

The problem is the external call:

```solidity
token.transfer(msg.sender, amount);
```

An external call may transfer execution to another contract. In this lab, the token deliberately invokes `onTokenReceived()` on the recipient during the transfer.

That callback allows the attacker to call `withdrawAll()` again before the first withdrawall has cleared the recorded balance.

The attacker therefore re-enters the function while the original balance is still available.

## 4. Attack execution

The attack is reproduced through the following sequence.

### Step 1 — Prepare the initial state

The victim deposits 100 tokens, and the attacker deposits another 100 tokens.

```text
Victim deposit:    100
Attacker deposit:  100
----------------------
Staking balance:   200
```

The staking contract holds 200 tokens and records 100 tokens for each participant.

### Step 2 — Enable the malicious callback

The test calls:

```solidity
token.startAttack();
```

This enables the callback in `ReentrantToken`. It does not execute the attack by itself.

The attacker then starts the withdrawall through:

```solidity
vulnerableAttacker.attack();
```

### Step 3 — First withdrawall

`VulnerableStaking.withdrawAll()` reads:

```text
balances[attacker] = 100
```

It then calls the token to transfer 100 tokens to the attacker.

At this point, the staking contract has not yet cleared the attacker's recorded balance.

### Step 4 — Callback and reentrancy

During the token transfer, `ReentrantToken` calls:

```solidity
IReentrancyReceiver(to).onTokenReceived();
```

The attacker receives the callback and invokes `withdrawAll()` again.

The second call reads the same recorded balance:

```text
balances[attacker] = 100
```

Because the vulnerable contract has not yet updated the balance, the second withdrawall passes the `amount > 0` check and initiates another transfer of 100 tokens.

The attacker contract limits the callback to one reentrant attempt using the `reentered` flag.

### Step 5 — Complete both withdrawalls

The attacker receives 100 tokens from the reentrant withdrawall and another 100 from the original withdrawall.

The final state is:

| Property | Before attack | After attack |
|---|---:|---:|
| Attacker token balance | 100 | 200 |
| Staking token balance | 200 | 0 |
| Attacker recorded balance | 100 | 0 |
| Victim recorded balance | 100 | 100 |

The staking contract's token balance is now zero, even though the victim's recorded balance remains 100 tokens.

The test demonstrates that the contract's accounting and its actual token holdings have become inconsistent.

## 5. Mitigation: Checks-Effects-Interactions

The protected implementation follows the CEI pattern.

Its withdrawall sequence is:

```solidity
uint256 amount = balances[msg.sender];

require(amount > 0, "Nothing to withdraw");

balances[msg.sender] = 0;

bool success = token.transfer(msg.sender, amount);
require(success, "Transfer failed");
```

The three stages are:

1. **Checks:** read the user's balance and verify that it is greater than zero.
2. **Effects:** set the user's recorded balance to zero.
3. **Interactions:** transfer the tokens through the external token contract.

The important difference is that the state is updated before execution is handed to the token contract.

### Why reentrancy fails

When the token invokes the attacker's callback, the attacker attempts a second call to `withdrawAll()`.

This time, the second call reads:

```text
balances[attacker] = 0
```

The following check fails:

```solidity
require(amount > 0, "Nothing to withdraw");
```

The second withdrawall reverts. In this lab, the callback error is not caught by the token, so the revert propagates through the external call and reverts the entire original withdrawall transaction.

### Final state after the protected attack

| Property | Before attack | After reverted transaction |
|---|---:|---:|
| Attacker token balance | 100 | 100 |
| Staking token balance | 200 | 200 |
| Attacker recorded balance | 100 | 100 |
| Victim recorded balance | 100 | 100 |

The attack is blocked, and both participants' deposits remain intact.

## 6. Role of the malicious token

The attack depends on the intentional callback implemented in `ReentrantToken.sol`.

The token transfers its balances and emits its `Transfer` event before calling the recipient's callback when attack mode is enabled.

This design is deliberately malicious and allows the lab to demonstrate how an external interaction can execute attacker-controlled code.

It is important not to generalize this behavior to all ERC-20 tokens. A standard token transfer does not inherently invoke a recipient callback. However, security reviews must account for external contracts that may behave unexpectedly or execute code during interactions.

## 7. Test coverage

The test suite verifies three scenarios.

| Test | Purpose |
|---|---|
| `test_SetUp()` | Verifies the initial token distribution. |
| `test_ReentrancyAttack()` | Confirms that reentrancy exploits the vulnerable implementation. |
| `test_ReentrancyAttackBlocked()` | Confirms that the protected implementation reverts and preserves the initial state. |

The tests check both token balances and recorded staking balances. This distinction is important: checking only the attacker's balance would not fully demonstrate the accounting inconsistency left by the vulnerable contract.

Run the tests from the `staking/` directory:

```bash
forge test -vv
```

For a more detailed execution trace:

```bash
forge test -vvvv
```

## 8. Limitations and further considerations

This lab demonstrates one specific reentrancy path and one mitigation.

The protected withdrawall function follows CEI for the balance being withdrawn, but that alone does not establish that the entire contract is secure.

A broader review should also consider:

- External calls made during `deposit()`, including `transferFrom()`.
- Validation of the token address in the constructor.
- The behavior of non-standard or malicious token implementations.
- Whether other functions can be combined into a reentrancy attack.
- Whether additional accounting invariants must be enforced.

The vulnerable implementation is intentionally retained as a reproducible example. It should not be deployed with real funds.

## 9. Conclusion

The experiment demonstrates that reentrancy can occur when a contract makes an external call before updating the state used to authorize that call.

In the vulnerable implementation, the attacker re-enters `withdrawAll()` while the original balance remains available and withdraws more tokens than its recorded deposit.

In the protected implementation, the balance is cleared before the external interaction. The reentrant withdrawall fails, and the transaction reverts atomically.

The central lesson is:

> Update the relevant contract state before making external calls whenever the correctness of that state is required to prevent repeated execution.
