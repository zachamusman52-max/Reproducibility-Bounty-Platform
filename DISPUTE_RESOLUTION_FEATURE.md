# Dispute Resolution System

## Feature Overview

A decentralized dispute resolution mechanism that allows replicators to challenge rejected replications through community voting with economic stakes. This creates a fair, transparent appeals process where reputation-weighted community members vote to overturn or uphold rejection decisions.

## Value Proposition

- **Fair Appeals Process**: Replicators can challenge unfair rejections through peer review
- **Economic Incentives**: Staking mechanisms ensure serious participation and deter frivolous disputes
- **Community Governance**: Decentralized voting distributes decision-making power
- **Time-Locked Decisions**: Voting periods ensure adequate deliberation time
- **Reward Distribution**: Winners receive their stakes back plus a share of loser stakes

## Technical Implementation

### Constants Added

```clarity
DISPUTE_STATUS_OPEN u1
DISPUTE_STATUS_RESOLVED_UPHELD u2
DISPUTE_STATUS_RESOLVED_REJECTED u3
MIN_DISPUTE_STAKE u1000000
DISPUTE_VOTING_PERIOD u144
MIN_DISPUTE_VOTES u3
```

### Data Structures

**disputes map**: Tracks dispute details including replication ID, disputer, voting results, and resolution status

**dispute-votes map**: Records individual votes with stakes and timestamps

**replication-disputes map**: Links replications to their disputes

**dispute-counter**: Global counter for dispute IDs

### Public Functions

#### create-dispute
Creates a new dispute for a rejected replication. Requires minimum stake and only replicator can dispute their own work.

**Parameters**: replication-id, reason, stake-amount

#### vote-on-dispute
Allows reputation-qualified users to vote on disputes with stakes. Votes are locked until resolution.

**Parameters**: dispute-id, vote-for (bool), stake-amount

#### resolve-dispute
Finalizes dispute after voting period. Distributes bounties if upheld, returns stakes based on outcome.

**Parameters**: dispute-id

#### claim-dispute-reward
Allows voters to claim their rewards after dispute resolution. Winners receive stakes plus rewards.

**Parameters**: dispute-id

### Read-Only Functions

- **get-dispute**: Retrieve dispute details
- **get-dispute-for-replication**: Find dispute by replication ID
- **get-dispute-vote**: Check individual vote records
- **get-dispute-status**: Get current voting status and deadlines

## Usage Flow

1. Replicator submits replication → Gets rejected
2. Replicator creates dispute with stake (≥1 STX) and reason
3. Community members vote during voting period (144 blocks)
4. After deadline, anyone resolves the dispute
5. If upheld: replicator receives bounty + stake back
6. If rejected: dispute fails, stake forfeited
7. Voters claim rewards proportional to their stakes

## Security Features

- Reputation requirements for voters (MIN_REVIEWER_REPUTATION)
- Economic stakes deter spam and ensure commitment
- Time-locked voting prevents rushed decisions
- Minimum vote threshold ensures adequate participation
- One vote per user prevents manipulation

## Error Codes

- ERR_DISPUTE_NOT_FOUND (451)
- ERR_DISPUTE_ALREADY_EXISTS (452)
- ERR_DISPUTE_CLOSED (453)
- ERR_ALREADY_VOTED (454)
- ERR_INSUFFICIENT_STAKE (455)
- ERR_DISPUTE_NOT_RESOLVED (456)
- ERR_DISPUTE_TIMEOUT_NOT_REACHED (457)
