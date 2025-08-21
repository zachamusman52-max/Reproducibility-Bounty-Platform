# 🔬 Reproducibility Bounty Platform

A blockchain-based platform that incentivizes scientific reproducibility through token-backed bounties. Researchers post studies with STX bounties, and independent labs earn rewards for successfully replicating results.

## 🌟 Features

- **📊 Study Registration**: Researchers can post studies with detailed methodology and bounty amounts
- **🔍 Replication Tracking**: Independent labs submit replication attempts with findings and data hashes
- **✅ Verification System**: Original researchers verify replication results
- **💰 Automated Rewards**: Successful replications automatically receive bounty payments
- **📈 Transparency**: All results and transactions recorded on-chain
- **📊 Success Metrics**: Real-time tracking of replication success rates

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet for testnet/mainnet interaction

### Installation
```bash
git clone https://github.com/your-repo/reproducibility-bounty-platform
cd reproducibility-bounty-platform
clarinet check
```

## 📋 Contract Functions

### Public Functions

#### `create-study`
Create a new study with bounty funding
```clarity
(create-study "Study Title" "Description" "Methodology" 1000000)
```
- **Parameters**: title, description, methodology, bounty-amount (in µSTX)
- **Returns**: Study ID

#### `submit-replication`
Submit a replication attempt for a study
```clarity
(submit-replication study-id "Replication findings" data-hash)
```
- **Parameters**: study-id, findings, data-hash (32 bytes)
- **Returns**: Replication ID

#### `verify-replication`
Verify a replication attempt (study owner only)
```clarity
(verify-replication replication-id true)
```
- **Parameters**: replication-id, is-successful (bool)
- **Returns**: Success status

#### `cancel-study`
Cancel an active study and refund bounty (owner only)
```clarity
(cancel-study study-id)
```

#### `withdraw-remaining-bounty`
Withdraw remaining bounty after study completion (owner only)
```clarity
(withdraw-remaining-bounty study-id)
```

### Read-Only Functions

#### `get-study`
Retrieve study details
```clarity
(get-study study-id)
```

#### `get-replication`
Retrieve replication details
```clarity
(get-replication replication-id)
```

#### `get-study-stats`
Get study statistics including success rate
```clarity
(get-study-stats study-id)
```

#### `get-platform-stats`
Get overall platform statistics
```clarity
(get-platform-stats)
```

## 💡 Usage Examples

### For Researchers

1. **Post a Study**
```clarity
;; Create study with 10 STX bounty
(contract-call? .reproducibility-bounty-platform create-study 
  "Effect of Compound X on Cell Growth"
  "Study investigating cellular response to treatment"
  "Standard protocol with control groups, n=100 samples"
  10000000)
```

2. **Review Replications**
```clarity
;; Check replication details
(contract-call? .reproducibility-bounty-platform get-replication u1)

;; Verify successful replication
(contract-call? .reproducibility-bounty-platform verify-replication u1 true)
```

### For Replicating Labs

1. **Find Active Studies**
```clarity
;; Get study details
(contract-call? .reproducibility-bounty-platform get-study u1)
```

2. **Submit Replication**
```clarity
;; Submit replication results
(contract-call? .reproducibility-bounty-platform submit-replication 
  u1
  "Successfully replicated with 95% correlation to original results"
  0x1234567890abcdef1234567890abcdef12345678)
```

## 📊 Data Structures

### Study Status
- `1`: Active - accepting replications
- `2`: Completed - study concluded
- `3`: Cancelled - study cancelled by researcher

### Replication Status
- `1`: Pending - awaiting verification
- `2`: Verified - confirmed successful
- `3`: Rejected - deemed unsuccessful

## 🔐 Security Features

- **Access Control**: Only study owners can verify replications and manage studies
- **Duplicate Prevention**: Users cannot submit multiple replications for the same study
- **Fund Protection**: Bounties held in contract escrow until verification

## 🧪 Testing

Run contract tests:
```bash
npm install
npm test
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 💬 Support

For questions and support, please open an issue in this repository.

---

*Building trust in science, one replication at a time* 🧬✨
