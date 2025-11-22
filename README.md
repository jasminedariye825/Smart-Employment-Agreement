# 💼 Smart Employment Agreement

> **Revolutionizing workplace fairness through blockchain technology** 🚀

A Clarity smart contract that creates transparent, enforceable employment agreements on the Stacks blockchain. Perfect for protecting both employers and employees in developing economies where traditional contract enforcement is challenging.

## 🎯 Problem We Solve

- **Wage Theft Prevention**: Automatic salary payments eliminate wage disputes
- **Contract Manipulation**: Immutable on-chain agreements prevent tampering
- **Legal Enforcement**: Automated penalties without lengthy court battles
- **Trust Building**: Performance-based hiring with transparent milestone tracking

## ✨ Key Features

### 🏗️ Core Functionality
- **On-Chain Employment Contracts** - Store salary terms, bonuses, and penalties immutably
- **Milestone-Based Payments** - Auto-execute payments upon completion verification
- **Breach Reporting System** - Report and resolve contract violations transparently
- **Penalty Enforcement** - Automatic penalty calculations based on violation severity
- **Bonus Distribution** - Reward exceptional performance with predefined bonus pools

### 🔒 Security Features
- **Multi-Party Authorization** - Both employer and employee must agree to key changes
- **Status Tracking** - Monitor agreement lifecycle (Active, Completed, Terminated, Breached)
- **Payment Verification** - Built-in STX transfer mechanisms with failure handling
- **Time-Based Validation** - Block height tracking for deadline enforcement

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Basic understanding of Clarity smart contracts
- STX tokens for contract deployment and payments

### Installation

1. Clone this repository:
```bash
git clone <your-repo-url>
cd Smart-Employment-Agreement
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

## 📖 Usage Guide

### 1. 📝 Creating an Employment Agreement

```clarity
(contract-call? .Smart-Employment-Agreement create-agreement
  'SP2...EMPLOYEE-ADDRESS     ;; Employee's principal
  u1000000                    ;; Base salary (1 STX in microSTX)
  u500000                     ;; Bonus pool (0.5 STX)
  u10                         ;; Penalty rate (10%)
  u52560                      ;; Duration (1 year in blocks)
)
```

**Parameters:**
- `employee`: The employee's Stacks address
- `base-salary`: Monthly/periodic salary in microSTX
- `bonus-pool`: Total bonus amount available
- `penalty-rate`: Percentage penalty for violations (0-100)
- `duration-blocks`: Contract duration in blocks

### 2. 🎯 Adding Milestones

```clarity
(contract-call? .Smart-Employment-Agreement add-milestone
  u1                          ;; Agreement ID
  "Complete project phase 1"  ;; Description
  u250000                     ;; Payment amount (0.25 STX)
  u2628                       ;; Due in ~18 days from start
)
```

### 3. ✅ Completing Milestones (Employer Only)

```clarity
(contract-call? .Smart-Employment-Agreement complete-milestone
  u1    ;; Agreement ID
  u1    ;; Milestone ID
)
```

### 4. 💰 Processing Salary Payments

```clarity
(contract-call? .Smart-Employment-Agreement pay-base-salary
  u1    ;; Agreement ID
)
```

### 5. 🎉 Distributing Bonuses

```clarity
(contract-call? .Smart-Employment-Agreement distribute-bonus
  u1        ;; Agreement ID
  u100000   ;; Bonus amount (0.1 STX)
)
```

### 6. 🚨 Reporting Contract Breaches

```clarity
(contract-call? .Smart-Employment-Agreement report-breach
  u1                              ;; Agreement ID
  "Missed deadline without notice" ;; Description
  u50000                          ;; Penalty amount
)
```

### 7. ⚖️ Resolving Breaches (Contract Owner Only)

```clarity
(contract-call? .Smart-Employment-Agreement resolve-breach
  u1      ;; Agreement ID
  u1      ;; Report ID
  true    ;; Penalty approved?
)
```

## 🔍 Read-Only Functions

### Get Agreement Details
```clarity
(contract-call? .Smart-Employment-Agreement get-agreement u1)
```

### Check Milestone Status
```clarity
(contract-call? .Smart-Employment-Agreement get-milestone u1 u1)
```

### Calculate Penalties
```clarity
(contract-call? .Smart-Employment-Agreement calculate-penalty u1 u3)
```

### Check if Agreement Expired
```clarity
(contract-call? .Smart-Employment-Agreement is-agreement-expired u1)
```

## 📊 Contract States

### Agreement Status
- `1` - **Active**: Contract is operational
- `2` - **Completed**: All terms fulfilled
- `3` - **Terminated**: Contract ended early
- `4` - **Breached**: Violation occurred

### Milestone Status
- `1` - **Pending**: Awaiting completion
- `2` - **Completed**: Successfully finished
- `3` - **Disputed**: Under review

## ⚠️ Important Notes

### Security Considerations
- Only employers can complete milestones and process payments
- Both parties can add milestones and report breaches
- Contract owner (deployer) resolves disputes
- All payments are automatically processed via STX transfers

### Best Practices
- Set realistic milestone deadlines
- Keep penalty rates reasonable (1-20%)
- Document breach reports thoroughly
- Maintain sufficient STX balance for payments

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Test individual functions in Clarinet console:
```bash
clarinet console
```

## 🤝 Contributing

We welcome contributions! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

Need help? 
- 📚 Check the [Clarity Documentation](https://docs.stacks.co/clarity/)
- 💬 Join the [Stacks Discord](https://discord.gg/stacks)
- 🐛 Report issues on GitHub

---

**Built with ❤️ for a fairer workplace future** 🌟

# Smart Employment Agreement

