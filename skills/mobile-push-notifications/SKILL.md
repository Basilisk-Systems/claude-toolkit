---
name: mobile-push-notifications
description: Push notification patterns for React Native + Expo apps with AWS Lambda backends. Covers APNs/FCM fundamentals, Expo Push API, permission UX, token management, and server-side delivery.
---

# Mobile Push Notifications

## Architecture Overview

```
EventBridge (cron) → Lambda (drift check) → Expo Push API → APNs/FCM → Device
                                                ↓
                                    Ticket IDs (async receipt check)
```

Expo Push API acts as a relay: your Lambda POSTs to Expo, Expo forwards to Apple (APNs) and Google (FCM). You never manage APNs certificates or FCM server keys directly.

---

## Platform Fundamentals (What Web Developers Don't Know)

### APNs (Apple Push Notification service)
- **Best-effort delivery** — Apple does NOT guarantee delivery. If device is off, only the LAST notification per app is stored (collapsed). No queue.
- **Token-based auth** — Expo manages this. You'd need a .p8 key from Apple Developer portal, uploaded to EAS.
- **Payload limit:** 4KB
- **Silent notifications** — `content-available: 1` wakes the app briefly for background processing (e.g., trigger sync). No user-visible alert. iOS throttles these (~2-3/hour).
- **Provisional authorization (iOS 12+)** — Notifications go to Notification Center quietly without prompting. User can then promote to prominent or turn off. Great for reducing permission friction.

### FCM (Firebase Cloud Messaging)
- **More reliable than APNs** — FCM queues up to 100 messages per device for 28 days
- **Notification channels (Android 8+)** — User controls per-channel importance. You MUST create channels or notifications are silent.
- **POST_NOTIFICATIONS permission (Android 13+)** — Must explicitly request like iOS. Before Android 13, notifications were on by default.
- **Payload limit:** 4KB (data message), notification message can be larger
- **No silent push equivalent** — Use FCM data messages + WorkManager for background work

### Delivery is NOT Reading
- Delivery rate is typically 95-98%. Not 100%.
- A delivered notification may be dismissed without reading.
- Never assume a push was read. Design for missed notifications (in-app alert banners on next open).

---

## Expo Push API

### Token Format
```
ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]
```

### Registration Flow (Client-Side)
```typescript
import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import Constants from 'expo-constants';
import { Platform } from 'react-native';

async function registerForPushNotifications(): Promise<string | null> {
  // Push notifications don't work on simulators
  if (!Device.isDevice) {
    console.warn('Push notifications require a physical device');
    return null;
  }

  // Android: create notification channel BEFORE requesting permission
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('drift-alerts', {
      name: 'Drift Alerts',
      importance: Notifications.AndroidImportance.HIGH,
      vibrationPattern: [0, 250, 250, 250],
      lightColor: '#FF231F7C',
    });
    await Notifications.setNotificationChannelAsync('reminders', {
      name: 'Logging Reminders',
      importance: Notifications.AndroidImportance.DEFAULT,
    });
    await Notifications.setNotificationChannelAsync('weekly-summary', {
      name: 'Weekly Summary',
      importance: Notifications.AndroidImportance.LOW,
    });
  }

  // Check existing permission
  const { status: existingStatus } = await Notifications.getPermissionsAsync();
  let finalStatus = existingStatus;

  // Request if not determined
  if (existingStatus !== 'granted') {
    const { status } = await Notifications.requestPermissionsAsync({
      ios: {
        allowAlert: true,
        allowBadge: true,
        allowSound: true,
        // Enable provisional for lower friction (goes to Notification Center quietly)
        allowProvisional: true,
      },
    });
    finalStatus = status;
  }

  if (finalStatus !== 'granted') {
    return null; // User denied — don't nag, show in-app alternative
  }

  // Get Expo push token
  const projectId = Constants.expoConfig?.extra?.eas?.projectId;
  const { data: token } = await Notifications.getExpoPushTokenAsync({ projectId });
  return token; // "ExponentPushToken[xxx]"
}
```

### Permission UX — When to Ask

**NEVER ask on first launch.** The iOS permission prompt is one-shot — if denied, user must go to Settings to re-enable. Maximize your one chance.

**Best practice for health apps:**
1. User completes onboarding and baseline setup
2. Show a pre-permission screen explaining the value: "Get alerted when your eating patterns drift from your baseline — before small changes become big ones"
3. User taps "Enable Alerts" → THEN trigger the system prompt
4. If denied, show an in-app banner: "Drift alerts available in Settings > Notifications"

### Handling Notifications (Client-Side)

```typescript
// app/_layout.tsx — Set up listeners in root layout
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';
import { useEffect, useRef } from 'react';

// Configure how notifications appear when app is foregrounded
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,   // Show even when app is open
    shouldPlaySound: false,  // Don't play sound if app is active
    shouldSetBadge: true,
  }),
});

export default function RootLayout() {
  const notificationListener = useRef<Notifications.EventSubscription>();
  const responseListener = useRef<Notifications.EventSubscription>();

  useEffect(() => {
    // Notification received (app in foreground)
    notificationListener.current = Notifications.addNotificationReceivedListener(
      (notification) => {
        // Update in-app state (e.g., show drift badge)
        const data = notification.request.content.data;
        if (data.type === 'drift-alert') {
          useDriftStore.getState().setNewAlert(data);
        }
      }
    );

    // User tapped the notification
    responseListener.current = Notifications.addNotificationResponseReceivedListener(
      (response) => {
        const data = response.notification.request.content.data;
        // Deep link to the relevant screen
        if (data.url) {
          router.push(data.url as string);
        }
      }
    );

    return () => {
      notificationListener.current?.remove();
      responseListener.current?.remove();
    };
  }, []);

  return <Stack />;
}
```

---

## Token Management

### Where to Store Tokens (DynamoDB)

**Option A: Attribute on PROFILE item (recommended for Iduna MVP)**
```
PK: USER#clerk_abc123
SK: PROFILE
pushTokens: ["ExponentPushToken[xxx]", "ExponentPushToken[yyy]"]
deviceTokenMap: {
  "device_a": "ExponentPushToken[xxx]",
  "device_b": "ExponentPushToken[yyy]"
}
```

Pros: One read gets user profile + tokens + timezone (all needed by drift Lambda).
Cons: UpdateExpression gets complex with array manipulation.

**Option B: Separate items per device**
```
PK: USER#clerk_abc123
SK: PUSH#device_a
token: "ExponentPushToken[xxx]"
updatedAt: "2026-06-15T..."
platform: "ios"
```

Pros: Clean TTL per device, simple put/delete. Query `begins_with(SK, 'PUSH#')` to get all tokens.
Cons: Extra query during notification send.

**Recommendation:** Option A for MVP. The drift Lambda already loads the PROFILE to get the user's timezone for scheduling. Adding `pushTokens` as an attribute means zero extra reads. Switch to Option B only if multi-device management becomes complex.

### Token Rotation
- Tokens change on: app reinstall, OS update, Expo SDK upgrade, rare platform rotation
- On every app launch, re-register and send token to backend. Use `PUT` semantics (upsert, not append).
- Remove tokens when Expo Push API returns `DeviceNotRegistered` error.

```typescript
// On app launch, always re-register token
useEffect(() => {
  registerForPushNotifications().then((token) => {
    if (token) {
      api.updatePushToken({
        token,
        deviceId: getDeviceId(), // expo-device or expo-application
        platform: Platform.OS,
      });
    }
  });
}, []);
```

---

## Server-Side (Python Lambda)

### Sending Notifications via Expo Push API

```python
import json
import urllib3

EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send"
http = urllib3.PoolManager()

def send_push_notification(
    tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
    channel_id: str = "drift-alerts",
) -> list[dict]:
    """Send push notifications via Expo Push API. Returns ticket list."""
    messages = [
        {
            "to": token,
            "title": title,
            "body": body,
            "sound": "default",
            "channelId": channel_id,  # Android notification channel
            "data": data or {},
            "priority": "high",
        }
        for token in tokens
    ]

    # Batch up to 100 per request
    tickets = []
    for i in range(0, len(messages), 100):
        batch = messages[i : i + 100]
        response = http.request(
            "POST",
            EXPO_PUSH_URL,
            body=json.dumps(batch),
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        result = json.loads(response.data.decode())
        tickets.extend(result.get("data", []))

    return tickets


def handle_push_receipts(ticket_ids: list[str]) -> list[str]:
    """Check receipts after ~15 minutes. Returns tokens to remove."""
    response = http.request(
        "POST",
        "https://exp.host/--/api/v2/push/getReceipts",
        body=json.dumps({"ids": ticket_ids}),
        headers={"Content-Type": "application/json"},
    )
    receipts = json.loads(response.data.decode()).get("data", {})

    tokens_to_remove = []
    for ticket_id, receipt in receipts.items():
        if receipt.get("status") == "error":
            error = receipt.get("details", {}).get("error")
            if error == "DeviceNotRegistered":
                tokens_to_remove.append(receipt.get("expoPushToken"))
    return tokens_to_remove
```

### Drift Alert Lambda Flow

```python
def handler(event, context):
    """EventBridge triggers this per-user based on their timezone."""
    user_id = event["detail"]["userId"]

    # Load profile (has pushTokens + timezone + baseline)
    profile = get_profile(user_id)
    if not profile.get("pushTokens"):
        return  # No tokens, nothing to send

    # Compute weekly drift
    drift = compute_weekly_drift(user_id, profile["baseline"])

    if drift.exceeds_threshold():
        tickets = send_push_notification(
            tokens=profile["pushTokens"],
            title="Drift Alert",
            body=f"Your {drift.category} calories are {drift.direction} {drift.percentage}% vs baseline this week.",
            data={
                "type": "drift-alert",
                "url": "/drift/weekly",
                "weekId": drift.week_id,
            },
            channel_id="drift-alerts",
        )

        # Store ticket IDs for async receipt checking (15 min delay)
        store_tickets_for_receipt_check(user_id, tickets)
```

### Receipt Checking Architecture

```
Drift Lambda → sends push → stores ticket IDs in SQS (15 min delay)
                                       ↓
               Receipt Lambda ← SQS (after 15 min) → check receipts
                                       ↓
                            Remove invalid tokens from DynamoDB
```

Use SQS with `DelaySeconds=900` (15 minutes) to async-check receipts. The receipt Lambda handles `DeviceNotRegistered` by removing stale tokens.

---

## Notification Types for Health Apps

### What Works
| Type | Frequency | Channel | Value |
|------|-----------|---------|-------|
| Drift alert (threshold exceeded) | 0-2/week | drift-alerts (HIGH) | Core value prop |
| Weekly summary | 1/week (Sunday PM) | weekly-summary (LOW) | "Your week at a glance" |
| Missing data nudge | 1/day max if no logs | reminders (DEFAULT) | "No meals logged today" |

### What Gets You Uninstalled
- More than 3 notifications/day
- Guilt-inducing language ("You missed your target!")
- Notifications during sleep hours
- Alerts that don't have actionable context
- Promotional notifications disguised as alerts

### Best Practices
- **Time-gate notifications** — Use user's IANA timezone from PROFILE. No alerts between 10pm-7am.
- **Frequency cap** — Max 1 drift alert per day even if multiple thresholds exceeded. Batch into one.
- **Positive framing** — "Your exercise consistency is strong this week" not just negative drift.
- **Actionable** — Deep link to the specific drift report, not the app home screen.
- **Respect quiet mode** — Check `Notifications.getPermissionsAsync()` for current channel settings.

---

## Testing Push Notifications

### Limitations
- **iOS Simulator:** Cannot receive push notifications. Period. Must use physical device.
- **Expo Go:** Limited push support. Use dev client build for real testing.
- **Android Emulator:** Works with FCM (Google Play Services required in emulator image).

### Testing Tools
1. **Expo Push Notification Tool** — `https://expo.dev/notifications` — Send test pushes by pasting token
2. **EAS Build (preview profile)** — Install dev build on physical device via QR code
3. **curl for direct API testing:**
```bash
curl -X POST https://exp.host/--/api/v2/push/send \
  -H "Content-Type: application/json" \
  -d '{
    "to": "ExponentPushToken[xxxxxx]",
    "title": "Drift Alert",
    "body": "Lunch calories up 15% vs baseline",
    "data": { "type": "drift-alert", "url": "/drift/weekly" }
  }'
```

---

## Common Pitfalls

1. **Asking permission on first launch** — You get one shot on iOS. Pre-permission screen first.
2. **Not creating Android channels** — Notifications are silent on Android 8+ without channels.
3. **Assuming delivery = read** — Always have in-app fallback (badge on drift tab, alert banner).
4. **Not handling token rotation** — Re-register on every app launch.
5. **Forgetting timezone** — User in PST gets alert at 3am because Lambda runs on UTC.
6. **Not checking receipts** — `DeviceNotRegistered` tokens waste API calls and may rate-limit you.
7. **Sending too many** — Notification fatigue is the #1 reason users disable notifications entirely.
8. **Large payloads** — 4KB limit. Don't embed the full drift report — send a summary + deep link.
