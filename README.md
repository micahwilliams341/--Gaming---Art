# 🎵 Music Royalties Splitter

🎮 **Gaming & Art** - Automatically split music earnings between artists, producers, and rights holders based on on-chain royalty logic.

## 🚀 Features

- 🎼 **Register Songs**: Create songs with custom royalty splits
- 👥 **Multiple Participants**: Support for up to 20 participants per song
- 💰 **Automatic Distribution**: Split earnings based on predefined percentages
- 🏦 **Withdraw System**: Participants can withdraw their earnings anytime
- 📊 **Track Earnings**: Monitor total earnings per song and participant
- 🔒 **Admin Controls**: Manage songs and update participant splits

## 📋 Contract Functions

### 🎵 Song Management
- `create-song` - Register a new song with participants and royalty splits
- `deactivate-song` - Deactivate a song from receiving royalties
- `update-participant-split` - Update participant percentage and role

### 💸 Payment Distribution
- `distribute-royalties` - Distribute earnings to all participants of a song
- `withdraw-earnings` - Withdraw available earnings to your wallet

### 📖 Read Functions
- `get-song` - Get song details
- `get-participant-split` - Get participant's split percentage and earnings
- `get-user-earnings` - Get total and withdrawn earnings for a user
- `get-available-earnings` - Get withdrawable amount for a user
- `get-contract-stats` - Get overall contract statistics

## 🛠️ Usage

### Creating a Song
```clarity
(contract-call? .gaming-art create-song 
  "My Awesome Track"
  (list 
    { participant: 'SP1..., percentage: u5000, role: "artist" }
    { participant: 'SP2..., percentage: u3000, role: "producer" }
    { participant: 'SP3..., percentage: u2000, role: "rights-holder" }
  )
)
```

### Distributing Royalties
```clarity
(contract-call? .gaming-art distribute-royalties u1 u1000000)
```

### Withdrawing Earnings
```clarity
(contract-call? .gaming-art withdraw-earnings)
```

## 📊 Percentage System

- Percentages use basis points (10000 = 100%)
- Example: 5000 = 50%, 2500 = 25%
- Total percentages for all participants must equal 10000

## 🔧 Development

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 📝 Contract Address

Deploy to Stacks mainnet or testnet using Clarinet.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is open source and available under the MIT License.

---

Built with ❤️ for the music industry on Stacks blockchain 🌟
