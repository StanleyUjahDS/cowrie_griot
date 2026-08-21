# Implementation Plan: Correct Swap and Send Features (Backend-Aligned)

Align the "Swap" and "Send" features with the Griot Backend requirements. The backend is the source of truth for transaction nonces, gas limits, and broadcasting. The frontend is responsible for local signing and displaying the resulting status.

## User Review Required

> [!IMPORTANT]
> **Nonce Management**: The backend manages nonces by fetching the chain's pending count and reserving it in the database. The frontend **MUST NOT** manually fetch nonces or override the backend-provided values.
> **Verification**: The backend broadcast API verifies that the signed transaction matches the prepared draft. Any discrepancy (e.g., changed recipient or amount) will cause the broadcast to fail.

## Proposed Changes

### Wallet Service Layer

#### [MODIFY] [swap_api_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/swap_api_service.dart)
- Update `getQuote` to handle the normalized backend response, including `transactionRequest`.
- Update `broadcastSwap` to call the backend's `/crypto/swap/broadcast` endpoint.
- Update `getStatus` to use the backend's `/crypto/swap/status` endpoint, passing all required parameters (`provider`, `bridge`, `quoteId`, etc.).

#### [MODIFY] [transaction_api_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/transaction_api_service.dart)
- Ensure `prepareNativeSend` and `prepareTokenSend` correctly capture the `unsignedTransaction` and `transactionId` returned by the backend.
- Update `broadcastTransaction` to use the backend's `/crypto/transactions/broadcast` endpoint, ensuring the `transactionId` is passed to allow the backend to verify the signed payload against its stored draft.
- Remove manual nonce fetching from `prepareNativeSend` (it should always come from the backend).

### Wallet UI Layer

#### [MODIFY] [swap_screen.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/screens/swap_screen.dart)
- Use the `transactionRequest` object provided in the swap quote directly for signing.
- Remove manual `getPendingNonce` and `estimateTransaction` calls during the swap flow.
- Improve the status polling to wait for the backend's `CONFIRMED` or `SUCCESS` status.

#### [MODIFY] [send_screen.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/screens/send_screen.dart)
- Use the `unsignedTransaction` provided by the backend's `prepare` call for signing.
- Do not attempt to override gas or nonce values.
- Update the status polling to use the backend's sync endpoint.

## Verification Plan

### Manual Verification
1.  **Swap Test**:
    - Perform a same-chain swap (e.g., ETH to USDC on Base).
    - Verify that the frontend uses the backend-provided `gasLimit` and `nonce`.
    - Verify that the transaction is signed locally and broadcast to the backend.
    - Verify that the UI updates when the backend status changes to `CONFIRMED`.
2.  **Send Test**:
    - Send a native token (e.g., ETH).
    - Verify that the frontend signs the backend's `unsignedTransaction` without modification.
    - Verify that the `transactionId` is correctly passed during broadcast.
    - Verify status updates via the backend.
