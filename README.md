# MultiChainKit

[![Tests](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml/badge.svg)](https://github.com/iossocket/MultiChainKit/actions/workflows/test.yml)

Swift SDK for Ethereum and StarkNet.

## Why?

Most Swift blockchain SDKs focus on a single chain. If you're building a wallet or dApp that needs to support multiple chains, you end up juggling different libraries with inconsistent APIs. MultiChainKit provides a unified interface so you can work with Ethereum and StarkNet using the same patterns.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/user/MultiChainKit.git", from: "0.1.0")
]

// Pick what you need
.target(name: "YourApp", dependencies: ["MultiChainKit"])  // everything
.target(name: "YourApp", dependencies: ["EthereumKit"])    // just Ethereum
.target(name: "YourApp", dependencies: ["StarkNetKit"])    // just StarkNet
```

Requires iOS 14+ / macOS 12+, Swift 5.10+.

## Usage

### Wallet

```swift
import MultiChainKit

// New wallet
let wallet = try MultiChainWallet.generate()
print(wallet.mnemonic)

// From existing mnemonic
let wallet = try MultiChainWallet(mnemonic: "abandon abandon abandon ...")
```

### Ethereum

```swift
import EthereumKit

let provider = EthereumProvider(chain: .sepolia)
try wallet.connectEthereum(provider: provider)

// Address
let address = wallet.ethereumAccount!.address.checksummed

// Balance
let balance = try await provider.send(
    request: wallet.ethereumAccount!.balanceRequest()
)
print("\(balance.inEther) ETH")

// Transfer
let txHash = try await wallet.ethereumAccount!.transfer(
    to: EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f...")!,
    amount: .ether(0.1),
    provider: provider
)
```

### StarkNet

```swift
import StarkNetKit

let provider = StarkNetProvider(chain: .sepolia)
try wallet.connectStarkNet(provider: provider)

// StarkNet accounts need deployment first
if try await !wallet.starknetAccount!.isDeployed {
    let receipt = try await wallet.starknetAccount!.deploy()
}

// Balance
let balance = try await provider.send(
    request: wallet.starknetAccount!.balanceRequest()
)

// Transfer
let txHash = try await wallet.starknetAccount!.transfer(
    to: StarkNetAddress("0x049d36570d4e46f48e99674bd3fcc84644ddd...")!,
    amount: Felt("0x38D7EA4C68000")!
)
```

## Structure

```
MultiChainKit
├── MultiChainCore     # Protocols, BIP39/32, shared types
├── EthereumKit        # Ethereum: secp256k1, RLP, EIP-1559
├── StarkNetKit        # StarkNet: STARK curve, Pedersen, account abstraction
└── MultiChainKit      # MultiChainWallet, ChainRegistry
```

## Status

| Chain    | Mainnet | Testnet     |
| -------- | ------- | ----------- |
| Ethereum | ✓       | ✓ (Sepolia) |
| StarkNet | ✓       | ✓ (Sepolia) |

What's done:

- Wallet generation and recovery (BIP39/BIP32)
- Basic transfers
- Balance queries

What's next:

- ERC20 tokens
- Contract calls
- Hardware wallets

## Related

- [web3swift](https://github.com/web3swift-team/web3swift)
- [starknet.swift](https://github.com/software-mansion/starknet.swift)

## License

MIT
