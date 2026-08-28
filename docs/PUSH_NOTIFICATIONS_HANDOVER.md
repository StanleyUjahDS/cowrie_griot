# Push Notifications Implementation Handover

This document outlines the end-to-end implementation of push notifications in the Griot Flutter app using Firebase Cloud Messaging (FCM).

## Architecture Overview

The system is designed to be **backend-authoritative** and **session-aware**. Device tokens are only registered with the backend after a successful wallet authentication to ensure notifications are delivered to the correct user identity.

### 1. Service Initialization
Located in `lib/core/services/push_notification_service.dart`.
- Requests notification permissions (Alert, Badge, Sound).
- Retrieves the unique FCM device token.
- Sets up listeners for foreground messages and token rotations.

### 2. Token Lifecycle Management
- **Registration:** Tokens are sent to `/api/notifications/devices` via `syncTokenWithBackend()` only after `AppStartupService` confirms an active authenticated session.
- **Refresh:** Automatically resyncs with the backend if Firebase rotates the token while the app is running.
- **Cleanup:** On logout, `unregisterCurrentDevice()` is called to remove the token from the backend database BEFORE the local session is wiped.

### 3. Deep Linking & Routing
Located in `lib/app.dart` and `lib/core/router/app_router.dart`.
- **`chat_message`**: Automatically navigates the user directly into the specific conversation using the `conversationId` payload.
- **`message_request`**: Directs the user to the pending requests screen.
- **Cold Starts:** Preserves the notification data if the app was closed, triggering the route as soon as the application shell is ready.

## API Contract Reference

### Register/Sync Device
`POST /api/notifications/devices`
```json
{
  "token": "FCM_TOKEN",
  "platform": "android|ios|web",
  "locale": "en-US"
}
```

### Unregister Device (Logout)
`DELETE /api/notifications/devices`
```json
{
  "token": "FCM_TOKEN"
}
```

## Security Best Practices
- **No Logging:** FCM tokens are excluded from production logs.
- **Authenticated Only:** Token registration requires a valid Bearer access token.
- **Platform Verification:** Correctly identifies the OS (Android/iOS) to allow the backend to use appropriate notification channels.
