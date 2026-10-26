# Griot Network Flutter Client

Griot is a production cross-platform social application combining messaging,
groups, channels, live Campfires, voice/video calling, reputation, wallets,
subscriptions, tipping, and blockchain-enabled payments.

This repository contains the Flutter client for iOS and Android. It is a
non-custodial wallet experience: private keys and recovery phrases remain
under local device protection and are never sent to the application backend.

## Technology

- Flutter/Dart
- Provider and ChangeNotifier state management
- GoRouter navigation
- Socket.IO realtime messaging and presence
- Firebase Cloud Messaging notifications
- ZEGO voice/video calling
- Web3 wallet and EVM integrations
- Google Mobile Ads and Unity LevelPlay mediation
- Local caching and secure storage

## Product areas

Chat, groups, channels, Campfires, calls, profiles, wallet assets, swaps,
tipping, Plus subscriptions, reputation, push notifications, and media.

## Documentation

- [Frontend technical documentation](docs/GRIOT_FRONTEND_TECHNICAL_DOCUMENTATION.md)
- [Push-notification handover](docs/PUSH_NOTIFICATIONS_HANDOVER.md)

## Links

- Product: https://griot.network
- Company: https://exodicenterprise.com

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Do not commit production secrets, wallet keys, signing credentials, or private
environment files.
