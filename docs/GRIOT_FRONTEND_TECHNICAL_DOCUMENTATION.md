# Griot Network Frontend: Technical Documentation

**Project:** Griot Network / Cowrie Flutter client  
**Repository:** `StanleyUjahDS/cowrie_griot`  
**Website:** https://griot.network  
**Document purpose:** Engineering reference, deployment hand-off, and PhD application evidence  
**Last reviewed:** 19 October 2026

## 1. System overview

Griot is a cross-platform Flutter application for community communication and Web3-enabled social interaction. The client presents direct messages, groups, channels, live Campfires, voice/video calling, profiles, notifications, reputation, wallet functionality, subscriptions, and mediated advertising.

The application follows a feature-first structure. Cross-cutting concerns live under `lib/core`; product capabilities live under `lib/features`; reusable legacy widgets remain under `lib/widgets` while they are migrated into feature packages.

The frontend is intentionally a non-custodial client. Wallet keys and recovery phrases are generated or protected locally and are not sent to the backend. The backend receives authenticated application requests, public wallet addresses, transaction metadata, and signed/verified payment information where a feature requires it.

## 2. Technology stack

| Layer | Implementation |
|---|---|
| UI/runtime | Flutter, Dart 3.10.x |
| State management | `provider` and `ChangeNotifier` providers |
| Navigation | `go_router`, including a stateful bottom-navigation shell |
| HTTP | `http` through the shared `ApiClient` |
| Realtime | Socket.IO client, presence, typing, receipts, Campfire events |
| Local persistence | SQLite (`sqflite`), SharedPreferences, secure storage |
| Authentication | Wallet-based nonce/signature flow plus refreshable sessions |
| Push notifications | Firebase Cloud Messaging; CallKit integration for calls |
| Calling | ZEGO Express Engine and native call integration |
| Wallet/Web3 | `web3dart`, BIP-39, cryptography utilities, in-app dApp browser |
| Monetisation | Apple/Google in-app purchase, Google Mobile Ads, Unity LevelPlay mediation |
| Media | Image/video/audio picking, compression, cached network images, S3-backed URLs |

The dependency manifest is `pubspec.yaml`. The application version is currently declared there and must be incremented together with store build numbers for releases.

## 3. Repository structure

```text
lib/
├── app.dart                         Application composition and notification routing
├── main.dart                        Flutter entry point and startup bootstrapping
├── core/
│   ├── cache/                       Local message and conversation cache
│   ├── config/                      API and environment configuration
│   ├── network/                     ApiClient, auth headers, error handling
│   ├── router/                      GoRouter and navigation shell
│   ├── security/                    Secure storage and device security helpers
│   ├── services/                    Notifications, ads, startup and navigation
│   ├── startup/                     Ordered startup orchestration
│   └── ui/                          Shared scaffolds, dialogs and widgets
└── features/
    ├── auth/                        Wallet/session authentication
    ├── chat/                        DMs, groups, channels, Campfires and calls
    ├── iap/                         Store subscriptions and Plus verification
    ├── local_auth/                  Biometrics and device authentication
    ├── miner/                       Reputation activity and progression
    ├── settings/                    Account, privacy, preferences and Plus
    ├── splash/                      Startup/splash experience
    ├── users/                       Profiles, relationships and user data
    └── wallet/                      Assets, transactions, swaps and dApps
```

## 4. Application lifecycle

`main.dart` initializes Flutter bindings, theme state, Firebase and the application composition. `app.dart` constructs the dependency graph and exposes services/providers through `Provider`/`ChangeNotifierProvider`.

The startup sequence is designed to avoid presenting an empty shell while authentication and cached user state are being restored:

1. Load theme and device-level settings.
2. Initialize Firebase/notification services when available.
3. Restore secure authentication/session state.
4. Initialize wallet and messaging dependencies.
5. Connect realtime services after an authenticated user is known.
6. Resolve the initial route through `AppRouter`.

The splash and startup services should remain non-blocking for optional services. An unavailable ad, analytics, or secondary API must not prevent the authenticated social client from opening.

## 5. Navigation and screen model

`lib/core/router/app_router.dart` defines the application route graph. The primary navigation is a `StatefulShellRoute.indexedStack`, preserving the state of Chat, Campfires, Reputation, and Wallet branches while users move between them.

Important route families include:

- `/chat` — conversation home with direct, group and channel sections.
- `/conversation/:conversationId` — direct, group, or channel destination selected from conversation metadata.
- `/campfires` — public live and scheduled Campfire discovery.
- `/campfires/create` — Campfire creation flow.
- `/miner` — reputation activity screen (legacy route name retained for compatibility).
- `/miner/rules` — reputation activity rules and tier explanation.
- `/wallet` — wallet overview and asset management.
- `/wallet/browser` — in-app dApp browser with an initial URL.
- `/settings/reputation` — detailed reputation profile.

Conversation routes accept a `Conversation` object as route extra when available. Deep links and push notifications can provide only an ID; the destination then hydrates missing metadata from the API.

## 6. State and data flow

The frontend uses `ChangeNotifier` providers as feature coordinators rather than putting API calls directly into widgets.

### MessagingProvider

Responsibilities include:

- conversation lists for direct messages, groups, and channels;
- message pagination, optimistic updates and deduplication;
- Socket.IO connection, room membership, presence, typing and receipts;
- unread counts, notification read state, pinned messages and reactions;
- local cache reconciliation.

Messages are reconciled by stable server ID or client message ID. Cached messages are painted immediately and then reconciled with the server. Message loads are guarded per conversation so route entry, socket reconnect, and notification handling cannot start duplicate requests.

### MiningProvider and ReputationProvider

The historical `MiningProvider` API remains for server compatibility, but the user-facing experience is reputation-first. The Reputation screen shows tier, points, activity, community share and progression factors rather than a token balance or estimated token reward.

### WalletProvider

Coordinates wallet accounts, chains, public assets, transaction state, token metadata, swaps, and dApp navigation. Sensitive key material is kept behind secure/local wallet services and must never be logged.

## 7. Chat experience and consistency rules

The chat flow is deliberately cache-first:

1. Chat home loads cached conversations and keeps them mounted during refresh.
2. Opening a conversation passes the cached conversation object where possible.
3. The message list paints cached messages immediately.
4. A single server reconciliation updates the list after the first frame.
5. A `New messages` divider marks messages received while the user was outside the conversation.
6. Date separators remain independent from unread boundaries.

The DM and group screens use reverse lists so the newest messages remain near the composer. Message insertion must preserve stable keys and avoid rebuilding one list item per incoming message. The back action returns to the existing shell route where possible rather than replacing the entire navigation stack.

## 8. Realtime and notification behavior

Socket.IO carries message, presence, typing, receipt and Campfire events. Reconnect handling re-authenticates, restores the active room, and requests reconciliation. Push notification payloads are normalized in `app.dart`; direct/group/channel notifications resolve a conversation before navigating.

Notifications must be deduplicated by event/message ID. A notification should not interrupt an active conversation with a duplicate route or mark a message unread while the user is already viewing that conversation.

## 9. Wallet and Web3 safety model

The wallet is non-custodial. The client should:

- display chain and token identity before signing;
- show recipient, contract, amount, and network clearly;
- reject malformed addresses and unsupported networks;
- never collect private keys or seed phrases through API calls;
- avoid treating an on-chain transaction as successful until the relevant receipt/confirmation is verified;
- present public blockchain data as immutable and externally controlled.

The in-app dApp browser includes an HBADG entry at `https://hbadgertoken.com/`. Marketing copy should remain factual and should not promise price appreciation, profit, or guaranteed returns.

## 10. Monetisation and advertising

The client supports Google Mobile Ads and Unity LevelPlay mediation. The mediation configuration is app/platform-specific; Android and iOS use separate app IDs, ad units, and placements. Rewarded ads are used for eligible reputation activity only after the SDK reports a completed reward. A failed, dismissed, or unavailable ad must never grant activity credit.

Current ad integration principles:

- initialize mediation once during startup;
- load ads ahead of the user action where possible;
- use test devices and test placements during development;
- grant rewards from the reward callback, not merely from `onAdClosed`;
- provide graceful no-fill behavior;
- keep ad requests out of screens with no meaningful content.

## 11. Privacy and permissions

The app requests permissions only when a feature needs them: camera/media, microphone, contacts, location-enabled features, notifications, and local authentication. The privacy policy and store declarations must remain synchronized with the actual SDK behavior.

The app should not log authentication tokens, seed phrases, raw biometric data, private message contents, or payment credentials. Debug logs must be reviewed before production builds.

## 12. Local development

Prerequisites:

- Flutter SDK compatible with Dart `^3.10.3`;
- Android Studio/SDK and an Android emulator or device;
- Xcode and CocoaPods for iOS development;
- Firebase configuration files for notification-enabled builds;
- valid development API endpoint and non-production credentials.

Typical commands:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

For release builds, verify Android signing, iOS provisioning, Firebase entitlements, notification capabilities, wallet configuration, store product IDs, and mediation app/ad-unit IDs.

## 13. Testing strategy

At minimum, test:

- cold start with and without a valid session;
- session refresh and logout;
- opening a cached conversation offline/slow-network;
- message send, retry, edit, delete, receipt and unread-divider behavior;
- group/channel membership and Campfire entry;
- voice/video call permissions and reconnects;
- wallet creation/import, chain switching and transaction rejection;
- Plus purchase verification and restore;
- rewarded ad completion, dismissal, no-fill and duplicate callbacks;
- push notification routing for direct, group, channel, Campfire and call events.

## 14. Release checklist

1. Run `flutter analyze` and all tests.
2. Confirm API base URL and environment flags.
3. Verify no debug tokens, seed phrases, private URLs, or test ad IDs are shipped.
4. Validate Android package name and iOS bundle ID.
5. Verify store subscription products and server verification.
6. Verify FCM and CallKit notification behavior on physical devices.
7. Verify LevelPlay/AdMob mediation and no-fill fallbacks.
8. Test wallet signing on each supported chain.
9. Review privacy disclosures and account deletion links.
10. Build signed artifacts and record the version/build number.

## 15. Research and PhD framing

Griot provides a useful applied research case study in decentralized social computing. Potential research dimensions include:

- cache-first consistency for realtime social interfaces;
- non-custodial identity and wallet UX;
- reputation progression as an alternative to token-first engagement;
- moderation, privacy, and public blockchain immutability;
- resilient mobile communication under intermittent connectivity;
- mediation and ethical monetisation in community applications.

For academic claims, distinguish implemented behavior from planned work. Cite measured experiments, anonymized logs, and reproducible test conditions rather than relying on screenshots or marketing statements.

## 16. Known boundaries

- The historical server API still contains mining terminology for compatibility; the frontend now presents the feature as reputation activity.
- Public blockchain records cannot be erased by the app.
- Ad availability and eCPM vary by country, device, consent state, and mediation fill.
- Estimated cloud costs and realtime availability depend on deployment configuration.
- A production security review should be repeated against the exact deployed backend and smart-contract revision.
