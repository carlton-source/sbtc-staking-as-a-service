# sBTC Staking-as-a-Service Smart Contract

A Clarity smart contract implementation for staking sBTC (Stacks Bitcoin) tokens with flexible lock periods and reward mechanisms.

## Overview

This smart contract enables users to stake their sBTC tokens and earn rewards based on the amount staked and lock duration. The contract implements a flexible staking mechanism with time-locked deposits and reward multipliers.

## Features

- **Minimum Stake**: 0.001 sBTC
- **Base Reward Rate**: 5% APR
- **Minimum Lock Period**: 1 month (2,628 blocks)
- **Flexible Lock Duration**: Higher rewards for longer lock periods
- **Reward Multipliers**: Lock duration-based bonus rewards
- **Secure Token Management**: Built-in validation and safety checks
- **Administrative Controls**: Configurable reward rates and token contract updates

## Contract Functions

### Core Staking Operations

#### `stake-tokens`

- Stakes sBTC tokens into the contract
- Parameters:
  - `sbtc-contract`: sBTC token contract reference
  - `amount`: Amount to stake (minimum 0.001 sBTC)
  - `lock-period`: Duration in blocks (minimum 2,628 blocks)

#### `claim-rewards`

- Claims accumulated staking rewards
- Automatically calculates and transfers earned rewards
- Updates staking statistics and position data

#### `unstake`

- Withdraws staked tokens after lock period expires
- Automatically claims any pending rewards
- Clears staking position data

### Read-Only Functions

#### `get-staker-position`

- Returns detailed staking information for an address
- Includes:
  - Staked amount
  - Start block
  - Lock period
  - Claimed rewards
  - Last claim block

#### `get-staking-stats`

- Returns aggregate staking statistics for an address
- Includes:
  - Total amount staked
  - Total rewards claimed
  - Number of stakes

#### `get-total-staked`

- Returns the total amount of sBTC staked in the contract

#### `calculate-rewards`

- Calculates pending rewards for a staker
- Considers:
  - Base reward rate
  - Lock period bonus
  - Time since last claim

### Administrative Functions

#### `update-rewards-rate`

- Updates the base reward rate
- Restricted to contract owner
- Maximum rate: 100% APR

#### `update-sbtc-token`

- Updates the sBTC token contract reference
- Restricted to contract owner
- Includes validation checks

## Error Codes

| Code | Description                      |
| ---- | -------------------------------- |
| u100 | Owner-only operation             |
| u101 | Address already has active stake |
| u102 | No stake found for address       |
| u103 | Insufficient balance             |
| u104 | Below minimum stake amount       |
| u105 | Lock period violation            |
| u106 | Invalid amount                   |
| u107 | Invalid contract                 |

## Security Features

1. **Lock Period Enforcement**

   - Minimum lock period of 1 month (2,628 blocks)
   - Prevents premature withdrawals

2. **Access Controls**

   - Owner-only administrative functions
   - Protected reward rate updates
   - Secure token contract updates

3. **Token Validation**

   - sBTC contract validation
   - Minimum stake requirements
   - Balance checks

4. **State Management**
   - Atomic operations
   - Consistent state updates
   - Protected position data

## Technical Details

### Constants

- Block time: ~10 minutes
- Blocks per year: 52,560
- Minimum stake: 0.001 sBTC (100,000 satoshis)
- Base reward rate: 5% APR (scaled by 100)

### Data Structures

#### Staker Position

```clarity
{
    amount: uint,
    start-block: uint,
    lock-period: uint,
    rewards-claimed: uint,
    last-claim-block: uint
}
```

#### Staking Stats

```clarity
{
    total-staked: uint,
    total-rewards-claimed: uint,
    stake-count: uint
}
```

## Usage Example

```clarity
;; Stake 0.01 sBTC for 3 months
(contract-call? .sbtc-staking stake-tokens .sbtc u1000000 u7884)

;; Claim rewards
(contract-call? .sbtc-staking claim-rewards .sbtc)

;; Unstake after lock period
(contract-call? .sbtc-staking unstake .sbtc)
```

## Best Practices

1. **Before Staking**

   - Ensure sufficient sBTC balance
   - Consider lock period carefully
   - Verify minimum stake requirements

2. **During Staking**

   - Monitor reward accumulation
   - Claim rewards periodically
   - Track lock period expiration

3. **Unstaking**
   - Wait for lock period completion
   - Claim all rewards before unstaking
   - Verify transaction success
