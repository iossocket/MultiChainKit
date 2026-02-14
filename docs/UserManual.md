# MultiChainKit User Manual

This document is the detailed usage guide for MultiChainKit, for developers integrating Ethereum and Starknet support into Swift applications. For project overview and installation, see the [README](../README.md).

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [Ethereum Accounts](#2-ethereum-accounts)
3. [Ethereum RPC and Provider](#3-ethereum-rpc-and-provider)
4. [Ethereum: Querying Balance and Nonce](#4-ethereum-querying-balance-and-nonce)
5. [Ethereum: Transfers](#5-ethereum-transfers)
6. [Message Signing (EIP-191)](#6-message-signing-eip-191)
7. [EIP-712 Typed Data Signing](#7-eip-712-typed-data-signing)
8. [Ethereum: Contract Calls and ABI](#8-ethereum-contract-calls-and-abi)
9. [Starknet Accounts](#9-starknet-accounts)
10. [Starknet RPC and Provider](#10-starknet-rpc-and-provider)
11. [Starknet: Transactions](#11-starknet-transactions)
12. [Starknet: Contract Interaction](#12-starknet-contract-interaction)
13. [SNIP-12 Typed Data Signing](#13-snip-12-typed-data-signing)
14. [MultiChainWallet](#14-multichainwallet)
15. [Types and API Reference](#15-types-and-api-reference)
16. [Troubleshooting and Testing](#16-troubleshooting-and-testing)

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
.target(name: "YourApp", dependencies: ["StarknetKit"])     // Starknet only
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

## 2. Ethereum Accounts

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
- `DerivationPath.starknet` — Starknet default (m/44'/9004'/0'/0/0)

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

## 3. Ethereum RPC and Provider

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

## 4. Ethereum: Querying Balance and Nonce

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

## 5. Ethereum: Transfers

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

## 8. Ethereum: Contract Calls and ABI

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

## 9. Starknet Accounts

### 9.1 StarknetSigner

Create a signer from a private key or mnemonic:

**From Felt private key:**

```swift
import StarknetKit

let privateKey = Felt("0x1234...")!
let signer = try StarknetSigner(privateKey: privateKey)
```

**From mnemonic (BIP32 + EIP-2645 key grinding):**

```swift
let signer = try StarknetSigner(mnemonic: "abandon abandon ...", path: .starknet)
let publicKey = signer.publicKeyFelt!
```

The mnemonic path derives a secp256k1 key via BIP32, then grinds it into a valid Stark private key using HMAC-SHA256 until the result is within the Stark curve order.

### 9.2 StarknetAccount

Combines a signer with a deployed address. Starknet uses account abstraction, so the account address is a contract:

```swift
let signer = try StarknetSigner(mnemonic: mnemonic, path: .starknet)
let pubKey = signer.publicKeyFelt!

// Compute the counterfactual address for an OpenZeppelin account
let address = try OpenZeppelinAccount().computeAddress(publicKey: pubKey, salt: pubKey)

// Create account (optionally with provider)
let provider = StarknetProvider(chain: .sepolia)
let account = StarknetAccount(signer: signer, address: address, chain: .sepolia, provider: provider)
```

### 9.3 StarknetAddress

```swift
let addr = StarknetAddress("0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7")!
addr.checksummed  // Checksummed hex string
addr.data         // 32-byte Data
```

---

## 10. Starknet RPC and Provider

### 10.1 Built-in Chains

```swift
Starknet.mainnet  // chainId: SN_MAIN
Starknet.sepolia  // chainId: SN_SEPOLIA
```

### 10.2 Creating a Provider

```swift
let provider = StarknetProvider(chain: .sepolia)

// Custom URLSession
let provider = StarknetProvider(chain: .mainnet, session: myURLSession)
```

### 10.3 Common Requests

```swift
// Chain state
let chainId: String = try await provider.send(request: provider.chainIdRequest())
let blockNum: UInt64 = try await provider.send(request: provider.blockNumberRequest())

// Account state
let nonceHex: String = try await provider.send(request: provider.getNonceRequest(address: addr))
let classHash: String = try await provider.send(request: provider.getClassHashAtRequest(address: addr))

// Contract call (read-only)
let call = StarknetCall(contractAddress: contractFelt, entrypoint: "balanceOf", calldata: [addressFelt])
let result: [String] = try await provider.send(request: provider.callRequest(call: call))

// Transaction receipt
let receipt: StarknetReceipt = try await provider.send(
    request: provider.getTransactionReceiptRequest(hash: txHashFelt)
)
```

### 10.4 Transaction Polling

Wait for a transaction to be accepted on-chain:

```swift
let receipt = try await provider.waitForTransaction(hash: txHashFelt)
// Throws ChainError.transactionFailed if rejected/reverted
// Throws ProviderError.timeout if deadline exceeded
```

Custom polling config:

```swift
let config = PollingConfig(intervalSeconds: 2, timeoutSeconds: 120)
let receipt = try await provider.waitForTransaction(hash: txHashFelt, config: config)
```

`StarknetBlockId` options: `.latest`, `.pending`, `.number(UInt64)`, `.hash(Felt)`.

---

## 11. Starknet: Transactions

### 11.1 Building and Signing InvokeV3

```swift
// Build unsigned transaction
let calls = [StarknetCall(contractAddress: contractFelt, entrypoint: "transfer", calldata: [to, amount])]
let tx = account.buildInvokeV3(calls: calls, resourceBounds: resourceBounds, nonce: nonce)

// Sign
let signed = try account.signInvokeV3(tx)

// Send
let response: StarknetInvokeTransactionResponse = try await provider.send(
    request: provider.addInvokeTransactionRequest(invokeV3: signed)
)
print(response.transactionHashFelt)
```

### 11.2 Execute with Auto Fee Estimation

`executeV3` handles nonce, fee estimation, signing, and broadcasting in one call:

```swift
let calls = [StarknetCall(contractAddress: contractFelt, entrypoint: "transfer", calldata: [to, amount])]
let response = try await account.executeV3(calls: calls, feeMultiplier: 1.5)

// Wait for confirmation
let receipt = try await provider.waitForTransaction(hash: response.transactionHashFelt)
```

### 11.3 Fee Estimation

```swift
let estimate = try await account.estimateFee(calls: calls, nonce: nonce)
print(estimate.overallFeeFelt)  // Total fee as Felt
```

### 11.4 Deploy Account

```swift
// Build and sign a deploy account transaction (V3)
let deployTx = StarknetDeployAccountV3(
    classHash: OpenZeppelinAccount().classHash,
    contractAddressSalt: pubKey,
    constructorCalldata: [pubKey],
    resourceBounds: resourceBounds,
    nonce: .zero,
    chainId: Starknet.sepolia.chainId
)
let signed = try account.signDeployAccountV3(deployTx)
let response: StarknetInvokeTransactionResponse = try await provider.send(
    request: provider.addDeployAccountTransactionRequest(deployV3: signed)
)
```

### 11.5 Multicall

Both `buildInvokeV3` and `executeV3` accept an array of calls, which are encoded as a multicall:

```swift
let calls = [
    StarknetCall(contractAddress: tokenA, entrypoint: "approve", calldata: [spender, amount]),
    StarknetCall(contractAddress: router, entrypoint: "swap", calldata: [tokenA, tokenB, amount])
]
let response = try await account.executeV3(calls: calls)
```

---

## 12. Starknet: Contract Interaction

### 12.1 Creating a StarknetContract

```swift
let abiJson = """
[
  { "type": "function", "name": "balanceOf", "inputs": [{"name": "account", "type": "core::felt252"}],
    "outputs": [{"type": "core::integer::u256"}], "state_mutability": "view" },
  { "type": "function", "name": "transfer", "inputs": [{"name": "to", "type": "core::felt252"},
    {"name": "amount", "type": "core::integer::u256"}], "outputs": [], "state_mutability": "external" }
]
"""
let contract = try StarknetContract(address: contractFelt, abiJson: abiJson, provider: provider)
```

### 12.2 Read-Only Call

```swift
// Decoded results (CairoValue)
let results = try await contract.call(function: "balanceOf", args: [.felt(addressFelt)])

// Raw Felt results
let raw = try await contract.callRaw(function: "balanceOf", args: [.felt(addressFelt)])
```

### 12.3 Write (Invoke)

`invoke` handles nonce, fee estimation, signing, and broadcasting:

```swift
let response = try await contract.invoke(
    function: "transfer",
    args: [.felt(toFelt), .u256(low: amountLow, high: amountHigh)],
    account: account,
    feeMultiplier: 1.5
)
```

### 12.4 Fee Estimation

```swift
let estimate = try await contract.estimateFee(
    function: "transfer",
    args: [.felt(toFelt), .u256(low: amountLow, high: .zero)],
    account: account,
    nonce: nonce
)
```

### 12.5 Event Fetching and Decoding

```swift
let (events, token) = try await contract.getEvents(
    eventName: "Transfer",
    fromBlock: .number(100_000),
    toBlock: .latest
)
for event in events {
    print(event.name)           // "Transfer"
    print(event.keys["from"])   // CairoValue
    print(event.data["value"])  // CairoValue
}
```

### 12.6 Common CairoValue Types

| Usage                                    | Description      |
| ---------------------------------------- | ---------------- |
| `.felt(Felt)`                            | felt252          |
| `.u128(Felt)`                            | u128             |
| `.u256(low: Felt, high: Felt)`           | u256             |
| `.bool(Bool)`                            | bool             |
| `.contractAddress(Felt)`                 | ContractAddress  |
| `.byteArray(CairoByteArray)`            | ByteArray        |
| `.array([CairoValue])`                  | Array<T>         |
| `.option(.some(CairoValue))` / `.none`  | Option<T>        |
| `.tuple([CairoValue])`                  | (T1, T2, ...)    |
| `.enum(variant: UInt, data: [CairoValue])` | Enum variant  |

---

## 13. SNIP-12 Typed Data Signing

SNIP-12 is Starknet's equivalent of EIP-712. Two revisions exist:

- **v0**: uses Pedersen hash, domain type is `StarkNetDomain`
- **v1**: uses Poseidon hash, domain type is `StarknetDomain`

### 13.1 Building Typed Data

```swift
let domain = SNIP12Domain(name: "MyDApp", version: "1", chainId: Starknet.sepolia.chainId)

let types: [String: [SNIP12Type]] = [
    "StarkNetDomain": [
        SNIP12Type(name: "name", type: "felt"),
        SNIP12Type(name: "version", type: "felt"),
        SNIP12Type(name: "chainId", type: "felt"),
    ],
    "Mail": [
        SNIP12Type(name: "from", type: "felt"),
        SNIP12Type(name: "to", type: "felt"),
        SNIP12Type(name: "contents", type: "felt"),
    ]
]

let message: [String: SNIP12Value] = [
    "from": .felt(senderFelt),
    "to": .felt(recipientFelt),
    "contents": .shortString("Hello!")
]

let typedData = SNIP12TypedData(
    types: types,
    primaryType: "Mail",
    domain: domain,
    message: message
)
```

### 13.2 Signing

```swift
let hash = try typedData.messageHash(accountAddress: account.addressFelt)
let signature = try account.signer.sign(feltHash: hash)
```

### 13.3 Revision 1 (Poseidon)

```swift
let domain = SNIP12Domain(name: "MyDApp", version: "1", chainId: Starknet.sepolia.chainId, revision: .v1)
// Use "StarknetDomain" (not "StarkNetDomain") in types dict
// v1 uses Poseidon hash internally
```

---

## 14. MultiChainWallet

`MultiChainWallet` derives both Ethereum and Starknet accounts from a single BIP39 mnemonic:

```swift
import MultiChainKit

var wallet = try MultiChainWallet(mnemonic: "abandon abandon ...")

// Access accounts
wallet.ethereum.address.checksummed  // Ethereum address
wallet.starknet.address.checksummed  // Starknet address

// Attach providers
try wallet.connectEthereum(provider: EthereumProvider(chain: .sepolia))
wallet.connectStarknet(provider: StarknetProvider(chain: .sepolia))

// Now use wallet.ethereum and wallet.starknet for transactions
let ethBalance: String = try await wallet.ethereum.provider!.send(request: wallet.ethereum.balanceRequest())
let response = try await wallet.starknet.executeV3(calls: calls)
```

Custom derivation paths and account type:

```swift
let wallet = try MultiChainWallet(
    mnemonic: mnemonic,
    ethereumPath: .ethereum.account(1),
    starknetPath: .starknet.account(1),
    starknetAccountType: OpenZeppelinAccount(),
    starknetChain: .mainnet
)
```

---

## 15. Types and API Reference

### 15.1 Ethereum Types

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

### 15.2 Starknet Types

| Type                          | Description                                                          |
| ----------------------------- | -------------------------------------------------------------------- |
| `StarknetAccount`             | Signable account; signer + address, build/sign/execute transactions  |
| `StarknetSigner`              | Stark curve signer; from private key, mnemonic, or Data             |
| `StarknetProvider`            | JSON-RPC wrapper; send, fee estimation, transaction polling          |
| `Starknet`                    | Chain definition; chainId, rpcURL, mainnet/sepolia                   |
| `StarknetAddress`             | 32-byte address; checksummed hex                                     |
| `Felt`                        | Field element (< 2^251 + 17*2^192 + 1); hex, arithmetic, Data       |
| `StarknetContract`            | Contract wrapper; call, invoke, estimateFee, getEvents, decodeEvent  |
| `CairoValue` / `CairoType`   | Cairo type codec; encode/decode calldata for all Cairo types         |
| `StarknetBlockId`             | latest / pending / number / hash                                     |
| `OpenZeppelinAccount`         | Account type; classHash, constructorCalldata, computeAddress         |
| `StarknetKeyDerivation`       | BIP32 + EIP-2645 key grinding into Stark curve                      |
| `SNIP12TypedData` / `SNIP12Domain` / `SNIP12Value` | SNIP-12 types and messageHash()                |
| `StarknetReceipt`             | Transaction receipt; status, events, fee, messages                   |
| `PollingConfig`               | Polling interval and timeout for waitForTransaction                  |

### 15.3 Wei Common API

```swift
Wei(hexString)           // Parse from "0x..."
Wei.fromEther(1)         // 1 ETH
Wei.fromGwei(20)         // 20 Gwei
wei.toEtherDecimal()     // Decimal
wei.toGweiDecimal()
wei.hexString            // "0x..."
```

### 15.4 Felt Common API

```swift
Felt("0x1234")           // From hex string
Felt(42)                 // From integer literal
Felt(data)               // From big-endian Data
felt.hexString           // "0x1234"
felt.bigEndianData       // 32-byte Data
felt.bigUIntValue        // BigUInt
Felt.fromShortString("SN_SEPOLIA")  // Short string encoding
felt.toShortString()     // Decode short string
```

### 15.5 Ethereum Provider Request Methods

- `getBalanceRequest(address:block:)`
- `getTransactionCountRequest(address:block:)`
- `sendRawTransactionRequest(_ rawTx:)`
- `callRequest(transaction:block:)`
- `estimateGasRequest(transaction:)`
- `transactionReceiptRequest(hash:)`
- `blockNumberRequest()`, `chainIdRequest()`, `maxPriorityFeePerGasRequest()`

### 15.6 Starknet Provider Request Methods

- `chainIdRequest()`, `blockNumberRequest()`
- `getNonceRequest(address:block:)`
- `getClassHashAtRequest(address:block:)`
- `callRequest(call:block:)`
- `estimateFeeRequest(invokeV3:)`, `estimateFeeRequest(invokeV1:)`
- `addInvokeTransactionRequest(invokeV3:)`, `addInvokeTransactionRequest(invokeV1:)`
- `addDeployAccountTransactionRequest(deployV3:)`, `addDeployAccountTransactionRequest(deployV1:)`
- `getEventsRequest(filter:)`
- `getTransactionByHashRequest(hash:)`, `getTransactionReceiptRequest(hash:)`, `getTransactionStatusRequest(hash:)`
- `waitForTransaction(hash:config:)`

---

## 16. Troubleshooting and Testing

### 16.1 Common Errors

**Ethereum:**

- **Invalid private key/mnemonic:** Ensure private key is 32 bytes; mnemonic passes BIP39 validation and matches the derivation path.
- **RPC returns 4xx/5xx:** Check URL, network, and RPC rate limits; use a custom `URLSession` if needed.
- **Signing fails:** Use `EthereumSignableAccount`, call `sign(transaction:)` on a `var tx`, then use `tx.rawTransaction`.
- **Contract call fails:** Verify ABI and function name/parameter types match the contract; write operations must be signed before `sendRawTransaction`.

**Starknet:**

- **Invalid private key:** Stark private key must be non-zero and less than the curve order (~2^251).
- **noProvider error:** Attach a provider to `StarknetAccount` before calling `executeV3`, `estimateFee`, or other network methods.
- **Transaction REJECTED/REVERTED:** Check the failure reason in `StarknetTransactionStatus`; common causes are insufficient fee, wrong nonce, or contract logic errors.
- **Contract function not found:** Ensure the function name matches the ABI exactly; interface functions are flattened into the functions dict.
- **Event decoding fails:** Event names are matched by short name (e.g. "Transfer", not the fully-qualified Cairo path).

### 16.2 Running Tests

```bash
swift test
```

Tests live in `Tests/EthereumKitTests/`, `Tests/StarknetKitTests/`, and `Tests/MultiChainKitTests/`; they cover accounts, signing, transactions, ABI, contracts, typed data, and more. They double as usage examples.

### 16.3 Examples and Further Docs

- Root [README](../README.md): installation, structure, status.
- [DESIGN.md](DESIGN.md): architecture and design.
- Unit tests in each module can be used as sample code.

---

_This document is updated with the codebase; if it diverges from the current API, rely on source and tests._
