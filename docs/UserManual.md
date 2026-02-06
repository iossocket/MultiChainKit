# MultiChainKit User Manual

This document is the detailed usage guide for MultiChainKit, for developers integrating Ethereum (and future multi-chain) support into Swift applications. For project overview and installation, see the [README](../README.md).

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Accounts](#2-accounts)
3. [RPC and Provider](#3-rpc-and-provider)
4. [Querying Balance and Nonce](#4-querying-balance-and-nonce)
5. [Transfers](#5-transfers)
6. [Message Signing (EIP-191)](#6-message-signing-eip-191)
7. [EIP-712 Typed Data Signing](#7-eip-712-typed-data-signing)
8. [Contract Calls and ABI](#8-contract-calls-and-abi)
9. [Types and API Reference](#9-types-and-api-reference)
10. [Troubleshooting and Testing](#10-troubleshooting-and-testing)

---

## 1. Quick Start

### 1.1 Adding Dependencies

In your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/iossocket/MultiChainKit.git", from: "0.1.0")
]

// Choose as needed
.target(name: "YourApp", dependencies: ["MultiChainKit"])   // everything
.target(name: "YourApp", dependencies: ["EthereumKit"])     // Ethereum only
.target(name: "YourApp", dependencies: ["MultiChainCore"])  // core only (BIP39/BIP32, etc.)
```

**Requirements:** iOS 14+ / macOS 12+, Swift 5.10+.

### 1.2 Minimal Example: Fetch Balance

```swift
import EthereumKit

let provider = EthereumProvider(chain: .sepolia)
let account = EthereumAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f...")!
let readOnly = EthereumAccount(address: account)

let balanceHex: String = try await provider.send(request: readOnly.balanceRequest())
let wei = Wei(balanceHex) ?? .zero
print("Balance: \(wei.toEtherDecimal()) ETH")
```

---

## 2. Accounts

### 2.1 Read-Only Account (EthereumAccount)

For querying only; cannot sign. Create from an address:

```swift
let address = EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!
let account = EthereumAccount(address: address)
// Use with balanceRequest(), nonceRequest(), etc.
```

### 2.2 Signable Account (EthereumSignableAccount)

Used for signing transactions, messages, EIP-712, etc. Two ways to create:

**From private key:**

```swift
let privateKeyData: Data = ... // 32 bytes
let signable = try EthereumSignableAccount(privateKey: privateKeyData)
let address = signable.address.checksummed
```

**From mnemonic:**

```swift
let mnemonic = "abandon abandon abandon ..."
let signable = try EthereumSignableAccount(mnemonic: mnemonic, path: .ethereum)
```

Common derivation paths (defined in `MultiChainCore`):

- `DerivationPath.ethereum` — Ethereum default (m/44'/60'/0'/0/0)
- `DerivationPath.starknet` — Starknet (planned)

Multiple account indices:

```swift
let path = DerivationPath.ethereum.account(0)   // first account
let path1 = DerivationPath.ethereum.account(1)  // second account
let signable = try EthereumSignableAccount(mnemonic: mnemonic, path: path)
```

### 2.3 Address and Checksum

```swift
let addr = EthereumAddress("0x70997970c51812dc3a010c7d01b50e0d17dc79c8")!
addr.checksummed  // EIP-55 checksum format for RPC display
addr.data         // 20-byte Data
```

---

## 3. RPC and Provider

### 3.1 Built-in Chains

```swift
Ethereum.mainnet  // chainId: 1
Ethereum.sepolia  // chainId: 11155111
```

### 3.2 Creating a Provider

```swift
// Using built-in chain
let provider = EthereumProvider(chain: .sepolia)

// Custom RPC
let provider = EthereumProvider(
    chainId: 1,
    name: "Ethereum",
    url: URL(string: "https://your-rpc.com")!,
    isTestnet: false
)
```

You can pass a custom `URLSession` (e.g. for proxy or custom headers):

```swift
let provider = EthereumProvider(chain: .mainnet, session: myURLSession)
```

### 3.3 Sending Requests

All RPC calls go through `provider.send(request:)`; the return type is specified by the generic:

```swift
// Single request
let balanceHex: String = try await provider.send(request: provider.getBalanceRequest(address: addr, block: .latest))

// Batch requests (returns [Result<R, ProviderError>])
let requests: [ChainRequest] = [...]
let results: [Result<String, ProviderError>] = try await provider.send(requests: requests)
```

---

## 4. Querying Balance and Nonce

### 4.1 Balance

```swift
// Using Account's balanceRequest (defaults to latest)
let balanceHex: String = try await provider.send(request: signable.balanceRequest())

// Or specify block
let balanceReq = readOnly.balanceRequest(at: .pending)
let balanceHex: String = try await provider.send(request: balanceReq)

// Parse as Wei
let wei = Wei(balanceHex) ?? .zero
print(wei.toEtherDecimal())  // Decimal, e.g. 1.5
print(wei.toGweiDecimal())   // Commonly used for gas price
```

### 4.2 Nonce

```swift
let nonceHex: String = try await provider.send(
    request: provider.getTransactionCountRequest(address: signable.address, block: .pending)
)
let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0
```

Use `block: .pending` when sending transactions so the nonce includes in-flight transactions.

### 4.3 Block and Transaction Receipt

```swift
// Current block number
let blockNumberHex: String = try await provider.send(request: provider.blockNumberRequest())

// Transaction receipt
let receipt: EthereumReceipt? = try await provider.send(
    request: provider.transactionReceiptRequest(hash: txHash)
)
```

`BlockTag` options: `.latest`, `.pending`, `.earliest`, `.number(UInt64)`.

---

## 5. Transfers

### 5.1 Full Flow (EIP-1559)

```swift
let provider = EthereumProvider(chain: .sepolia)
let signable = try EthereumSignableAccount(privateKey: privateKeyData)

// 1. Get nonce
let nonceHex: String = try await provider.send(
    request: provider.getTransactionCountRequest(address: signable.address, block: .pending)
)
let nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0

// 2. Build transaction (EIP-1559)
var tx = signable.transferTransaction(
    to: EthereumAddress("0x70997970C51812dc3A010C7d01b50e0d17dc79C8")!,
    value: Wei.fromEther(1),
    nonce: nonce,
    maxPriorityFeePerGas: Wei.fromGwei(2),
    maxFeePerGas: Wei.fromGwei(30),
    chainId: provider.chain.chainId
)

// 3. Sign (must use signable account)
try signable.sign(transaction: &tx)

// 4. Send
guard let rawTx = tx.rawTransaction else { return }
let txHash: String = try await provider.send(request: provider.sendRawTransactionRequest(rawTx))
```

### 5.2 Gas and Custom Transactions

`transferTransaction` uses a fixed `gasLimit: 21000`. For contract calls or custom `data`, build an `EthereumTransaction` yourself:

```swift
var tx = EthereumTransaction(
    chainId: chainId,
    nonce: nonce,
    maxPriorityFeePerGas: Wei.fromGwei(2),
    maxFeePerGas: Wei.fromGwei(30),
    gasLimit: 100_000,
    to: contractAddress,
    value: .zero,
    data: calldata
)
try signable.sign(transaction: &tx)
```

You can also use factory methods: `EthereumTransaction.eip1559(...)`, `.legacy(...)`, `.eip2930(...)`.

### 5.3 Getting Gas Suggestions

```swift
let maxPriorityHex: String = try await provider.send(request: provider.maxPriorityFeePerGasRequest())
// Or eth_gasPrice, eth_feeHistory, etc., then convert to Wei for building
```

---

## 6. Message Signing (EIP-191)

Personal message signing (`personal_sign` / EIP-191 prefixed message):

```swift
let message = "Hello, Ethereum"
let signature = try signable.signMessage(message)
// signature.v, signature.r, signature.s can be used for on-chain or backend verification
```

**Recover signer address:**

```swift
let recovered = try signable.recoverMessageSigner(message: "Hello, Ethereum", signature: signature)
// recovered should match signable.address
```

`Data` is also supported: `signMessage(_ message: Data)`.

---

## 7. EIP-712 Typed Data Signing

Used for structured data signing in DApps (e.g. sign-in, approvals).

### 7.1 Building TypedData

```swift
import EthereumKit

let domain = EIP712Domain(
    name: "MyDApp",
    version: "1",
    chainId: 11155111,
    verifyingContract: EthereumAddress("0x...")!
)

let message: [String: EIP712Value] = [
    "from": .address(signable.address),
    "nonce": .uint(Wei(1)),
    "contents": .string("Welcome!")
]

let typedData = EIP712TypedData(
    types: [
        "EIP712Domain": [
            EIP712Type(name: "name", type: "string"),
            EIP712Type(name: "version", type: "string"),
            EIP712Type(name: "chainId", type: "uint256"),
            EIP712Type(name: "verifyingContract", type: "address")
        ],
        "Welcome": [
            EIP712Type(name: "from", type: "address"),
            EIP712Type(name: "nonce", type: "uint256"),
            EIP712Type(name: "contents", type: "string")
        ]
    ],
    primaryType: "Welcome",
    domain: domain,
    message: message
)
```

### 7.2 Signing

EIP-712: compute the hash to sign, then sign with the account:

```swift
let hashToSign = try typedData.signHash()
let signature = try signable.sign(hash: hashToSign)
// Pass signature or hex to frontend/backend for verification
```

---

## 8. Contract Calls and ABI

### 8.1 Using EthereumContract (Recommended)

Create a contract wrapper with address, ABI, and provider:

```swift
let contractAddress = EthereumAddress("0x...")!
let abiJson = """
[
  { "type": "function", "name": "balanceOf", "inputs": [{ "name": "account", "type": "address" }], "outputs": [{ "type": "uint256" }] },
  { "type": "function", "name": "transfer", "inputs": [{ "name": "to", "type": "address" }, { "name": "amount", "type": "uint256" }], "outputs": [] }
]
"""
let contract = try EthereumContract(address: contractAddress, abiJson: abiJson, provider: provider)
```

**Read-only call (eth_call):**

```swift
let results = try await contract.read(
    functionName: "balanceOf",
    args: [.address(userAddress)],
    block: .latest
)
let balance = results.first?.as(Wei.self)

// Or single-value helper
let balance: Wei = try await contract.readSingle(functionName: "balanceOf", args: [.address(userAddress)])
```

**Encode write and send transaction:**

```swift
let calldata = try contract.encodeWrite(
    functionName: "transfer",
    args: [.address(toAddress), .uint256(Wei.fromEther(1))]
)

var tx = EthereumTransaction(
    chainId: provider.chain.chainId,
    nonce: nonce,
    maxPriorityFeePerGas: maxPriorityFeePerGas,
    maxFeePerGas: maxFeePerGas,
    gasLimit: 100_000,
    to: contract.address,
    value: .zero,
    data: calldata
)
try signable.sign(transaction: &tx)
let txHash: String = try await provider.send(request: provider.sendRawTransactionRequest(tx.rawTransaction!))
```

**Estimate gas:**

```swift
let estimatedGas: Wei = try await contract.estimateGas(
    functionName: "transfer",
    args: [.address(to), .uint256(amount)],
    from: signable.address,
    value: .zero
)
```

**Event logs:**

```swift
struct TransferArgs {
    let from: EthereumAddress
    let to: EthereumAddress
    let value: Wei
}

let logs: [DecodedLog] = try await contract.getLogs(
    eventName: "Transfer",
    fromBlock: .number(12_000_000),
    toBlock: .latest,
    filter: nil
)
for log in logs {
    let args = log.args  // [ABIValue], decoded in ABI order
}
```

### 8.2 Manual ABI Encoding (Without ABI String)

When you only have the function signature, encode call data directly:

```swift
let selector = ABIValue.functionSelector("transfer(address,uint256)")
let args: [ABIValue] = [
    .address(EthereumAddress("0x7099...")!),
    .uint256(Wei.fromEther(1))
]
let calldata = ABIValue.encodeCall(signature: "transfer(address,uint256)", arguments: args)
// Set calldata as transaction.data
```

### 8.3 Common ABIValue Types

| Usage                                | Description   |
| ------------------------------------ | ------------- |
| `.address(EthereumAddress)`          | address       |
| `.uint256(Wei)` / `.uint256(UInt64)` | uint256       |
| `.bool(Bool)`                        | bool          |
| `.string(String)`                    | string        |
| `.bytes(Data)`                       | bytes         |
| `.fixedBytes(Data)`                  | bytes32       |
| `.tuple([ABIValue])`                 | tuple         |
| `.array([ABIValue])`                 | dynamic array |

Decode contract return data with `ABIValue.decode(types:data:)` or via `EthereumContract.read`; for single values use `result.as(Wei.self)`, `result.as(EthereumAddress.self)`, etc.

---

## 9. Types and API Reference

### 9.1 Core Types Quick Reference

| Type                                               | Description                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------ |
| `EthereumAccount`                                  | Read-only account (address only); balance/nonce queries            |
| `EthereumSignableAccount`                          | Signable account; private key/mnemonic, transfers, message signing |
| `EthereumProvider`                                 | JSON-RPC wrapper; `send(request:)` / `send(requests:)`             |
| `Ethereum`                                         | Chain definition; chainId, name, rpcURL, mainnet/sepolia           |
| `EthereumAddress`                                  | 20-byte address; EIP-55 checksum                                   |
| `Wei`                                              | Big-int amount; hex, Gwei/Ether conversion, arithmetic             |
| `EthereumTransaction`                              | Transaction (Legacy / EIP-2930 / EIP-1559); signing and RLP        |
| `EthereumContract`                                 | Contract wrapper; read, encodeWrite, estimateGas, getLogs          |
| `ABIValue`                                         | ABI encode/decode values; encodeCall, functionSelector             |
| `BlockTag`                                         | latest / pending / earliest / number                               |
| `EIP712TypedData` / `EIP712Domain` / `EIP712Value` | EIP-712 types and signHash()                                       |

### 9.2 Wei Common API

```swift
Wei(hexString)           // Parse from "0x..."
Wei.fromEther(1)         // 1 ETH
Wei.fromGwei(20)         // 20 Gwei
wei.toEtherDecimal()     // Decimal
wei.toGweiDecimal()
wei.hexString            // "0x..."
```

### 9.3 Provider Request Methods

- `getBalanceRequest(address:block:)`
- `getTransactionCountRequest(address:block:)`
- `sendRawTransactionRequest(_ rawTx:)`
- `callRequest(transaction:block:)`
- `estimateGasRequest(transaction:)`
- `transactionReceiptRequest(hash:)`
- `blockNumberRequest()`, `chainIdRequest()`, `maxPriorityFeePerGasRequest()`

---

## 10. Troubleshooting and Testing

### 10.1 Common Errors

- **Invalid private key/mnemonic:** Ensure private key is 32 bytes; mnemonic passes BIP39 validation and matches the derivation path.
- **RPC returns 4xx/5xx:** Check URL, network, and RPC rate limits; use a custom `URLSession` if needed.
- **Signing fails:** Use `EthereumSignableAccount`, call `sign(transaction:)` on a `var tx`, then use `tx.rawTransaction`.
- **Contract call fails:** Verify ABI and function name/parameter types match the contract; write operations must be signed before `sendRawTransaction`.

### 10.2 Running Tests

```bash
swift test
```

Tests live in `Tests/EthereumKitTests/` and cover accounts, signing, transactions, ABI, EIP-712, Provider, etc.; they double as usage examples.

### 10.3 Examples and Further Docs

- Root [README](../README.md): installation, structure, status.
- [DESIGN.md](DESIGN.md): architecture and design.
- Unit tests in each module can be used as sample code.

---

_This document is updated with the codebase; if it diverges from the current API, rely on source and tests._
