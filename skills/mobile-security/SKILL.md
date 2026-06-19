---
name: mobile-security
description: Mobile application security for React Native + Expo health apps. Covers threat model, secure storage, auth tokens, data encryption, privacy compliance, and health data protection.
---

# Mobile Application Security

## Mobile Threat Model — What's Different from Web

On web, you control the server. On mobile, the device is untrusted.

| Threat | Web | Mobile |
|--------|-----|--------|
| Code inspection | Minified but readable | Hermes bytecode decompilable, native libs reversible |
| Credential extraction | Browser devtools (same-session) | Extract from APK/IPA, decompile, read strings |
| Man-in-the-middle | Possible on public WiFi | Same + user can install proxy CA certs |
| Physical device theft | N/A | Full disk access if device unlocked, Keychain survives uninstall (iOS) |
| Malicious apps on device | Browser sandbox isolates tabs | Clipboard reading, screen recording, accessibility attacks |
| Client-side tampering | Limited (server validates) | Jailbreak/root bypasses all client-side controls |

**Bottom line:** Never trust anything from the client. All security-critical logic lives server-side. Client-side checks are UX conveniences, not security controls.

---

## Secure Storage

### What Goes Where

| Data | Storage | Why |
|------|---------|-----|
| Clerk JWT / refresh token | `expo-secure-store` | Encrypted at OS level |
| Push notification token | `expo-secure-store` or `AsyncStorage` | Not sensitive, but convenient in secure store |
| expo-sqlite database | Plain SQLite (OS-encrypted at rest on iOS) | See Data at Rest section |
| API base URL, public config | `AsyncStorage` or constants | Not sensitive |
| User preferences (theme, units) | `AsyncStorage` | Not sensitive |

### expo-secure-store
```typescript
import * as SecureStore from 'expo-secure-store';

// Store Clerk token (2KB size limit per item)
await SecureStore.setItemAsync('clerk_token', token, {
  keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  // iOS: only accessible when device is unlocked, not transferable to new device
});

const token = await SecureStore.getItemAsync('clerk_token');
await SecureStore.deleteItemAsync('clerk_token');
```

**Limits:**
- 2KB per item (iOS Keychain limit)
- Synchronous on Android (EncryptedSharedPreferences), async on iOS (Keychain)
- iOS Keychain data **survives app uninstall** — must explicitly clear on "sign out"

### The iOS Keychain Persistence Trap
```typescript
// On logout, explicitly clear ALL secure store items
async function logout() {
  await SecureStore.deleteItemAsync('clerk_token');
  await SecureStore.deleteItemAsync('push_token');
  await SecureStore.deleteItemAsync('device_id');
  // Also clear AsyncStorage
  await AsyncStorage.clear();
  // Also clear expo-sqlite database
  await db.closeAsync();
  await FileSystem.deleteAsync(db.databasePath);
}
```

If you don't clear Keychain on logout, a user who uninstalls and reinstalls could get auto-logged-in with a stale/expired token, leading to confusing errors.

---

## Authentication Security (Clerk)

### Token Handling Pattern
```typescript
import { useAuth } from '@clerk/clerk-expo';
import * as SecureStore from 'expo-secure-store';

// Clerk's expo package handles token storage automatically
// It uses expo-secure-store internally via tokenCache

// Custom token cache for Clerk (required in Expo)
const tokenCache = {
  async getToken(key: string) {
    return await SecureStore.getItemAsync(key);
  },
  async saveToken(key: string, value: string) {
    await SecureStore.setItemAsync(key, value);
  },
  async clearToken(key: string) {
    await SecureStore.deleteItemAsync(key);
  },
};

// In root layout
<ClerkProvider
  publishableKey={CLERK_KEY}
  tokenCache={tokenCache}
>
```

### API Request Pattern
```typescript
// Always get fresh token before API calls
async function apiRequest(path: string, options: RequestInit = {}) {
  const { getToken } = useAuth();
  const token = await getToken(); // Clerk handles refresh automatically

  return fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      ...options.headers,
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });
}
```

### Session Management
- Clerk manages session expiry and token refresh automatically
- Set reasonable session lifetime (7-30 days for mobile — longer than web)
- On 401 response from API, trigger Clerk re-auth (not manual token refresh)
- Support biometric re-auth for sensitive operations (changing baseline, deleting data)

---

## Data at Rest

### expo-sqlite Encryption

expo-sqlite is **NOT encrypted by default.** The database file is plain SQLite on disk.

**iOS Data Protection:** iOS encrypts all app files at rest when the device is locked (Complete Protection class). Your SQLite DB is encrypted by the OS — but accessible when the device is unlocked. This is sufficient for most B2C health apps.

**Android:** No automatic file-level encryption on all devices. Newer devices (Android 10+) have file-based encryption, but it varies.

**Should Iduna encrypt the database?**

For MVP: **No.** Here's the risk assessment:
- The data (meal calories, exercise duration, weight) is not high-sensitivity like banking or medical records
- HealthKit/Health Connect data on the same device is stored with the same protection level
- Adding SQLCipher adds ~2MB to app size, complexity, and performance overhead
- iOS Data Protection already covers the common case

For post-MVP: Consider SQLCipher if:
- You add more sensitive data (medical notes, medication tracking)
- A security audit flags it
- Enterprise/HIPAA customers demand it (not applicable to B2C)

### Sensitive Data Never on Disk
```typescript
// NEVER write these to expo-sqlite or AsyncStorage
// - Raw Clerk tokens (use expo-secure-store)
// - Payment information (RevenueCat handles this)
// - Health data not needed offline (import job status)
```

---

## Network Security

### TLS
- iOS enforces App Transport Security (ATS) — HTTPS only by default
- Android enforces cleartext block on API 28+ by default
- Both platforms enforce TLS 1.2 minimum
- **You don't need to do anything** — the defaults are secure

### Certificate Pinning — Usually Don't

Certificate pinning is when your app only trusts specific certificates, not the device's CA store.

**Risks outweigh benefits for Iduna:**
- If you rotate your cert (or your CDN rotates it), pinned apps break
- Users with expired apps can't connect at all — no graceful degradation
- OTA update can fix JS code but NOT native networking config
- Enterprise proxy users (common for testing) can't use the app

**When pinning makes sense:** Banking apps, apps handling financial transactions, apps required by compliance to pin.

**Iduna recommendation:** Don't pin. CloudFront + WAF + TLS 1.2 is sufficient. Your API Gateway already validates the Clerk JWT server-side.

### No Secrets in the Bundle
```typescript
// BAD — extractable from decompiled bundle
const API_KEY = "sk_live_abc123";

// GOOD — public keys only, validated server-side
const CLERK_PUBLISHABLE_KEY = process.env.EXPO_PUBLIC_CLERK_KEY;
// "EXPO_PUBLIC_" prefix means it's embedded in the JS bundle — only use for PUBLIC keys

// GOOD — sensitive operations go through your API
// Client: POST /v1/sync (with Clerk JWT)
// Server: Lambda validates JWT, then accesses DynamoDB with IAM role
```

---

## Privacy Compliance on Mobile

### iOS App Tracking Transparency (ATT)
- Required since iOS 14.5 if you track users across apps/websites
- **Iduna does NOT need ATT** if:
  - No advertising SDKs (Facebook, Google Ads)
  - No cross-app tracking
  - Analytics are first-party only (Expo analytics, your own Sentry)
- If you add any advertising SDK later, you MUST implement ATT

### App Privacy Labels (iOS)

Required in App Store Connect. For Iduna:

| Data Type | Collected | Linked to Identity | Used for Tracking |
|-----------|-----------|-------------------|-------------------|
| Health & Fitness | Yes | Yes | No |
| Body Measurements (weight) | Yes | Yes | No |
| Contact Info (email) | Yes | Yes | No |
| Identifiers (user ID) | Yes | Yes | No |
| Diagnostics (crash logs) | Yes | No | No |

### Data Safety Section (Google Play)

Similar to Apple's privacy labels. Declare:
- Data collected: Health info, email, user IDs
- Data shared: None (or specify if analytics shared)
- Security practices: Encrypted in transit, user can request deletion
- Data deletion: Describe how user can request full data deletion

### GDPR Consent on Mobile

```typescript
// Show consent screen on first launch for EU users
// (or for all users if not geo-gating)
function GdprConsentScreen() {
  return (
    <View>
      <Text>Iduna collects health and nutrition data to detect drift from your baseline.</Text>
      <Text>Your data is stored securely and never shared with third parties.</Text>
      <Pressable onPress={acceptAndContinue}>
        <Text>I Agree</Text>
      </Pressable>
      <Pressable onPress={viewPrivacyPolicy}>
        <Text>Privacy Policy</Text>
      </Pressable>
    </View>
  );
}
```

### Data Deletion (GDPR Right to Erasure)
- Must support "Delete my account and all data" from within the app
- Apple requires this since 2022 for apps with account creation
- Google requires this since 2024
- Server-side: Delete all DynamoDB items for PK=`USER#id`, revoke Clerk session, delete RevenueCat subscriber

---

## Health Data Specific Security

### Apple's Health Data Rules
- HealthKit data must not be stored in iCloud (Apple enforces this at API level)
- HealthKit data must not be sold to advertising platforms, data brokers, etc.
- Must disclose health data usage in privacy policy
- HealthKit data should not be shared with third parties without explicit user consent

### What You CAN Do
- Read health data and display insights to the user
- Upload health data to YOUR server for the user's benefit (drift analysis)
- Cache health data locally for offline access
- Use health data for notifications (drift alerts)

### What You CANNOT Do
- Share health data with advertisers
- Use health data for insurance underwriting
- Store health data in a way that's identifiable to third parties
- Access health data without clear user consent

---

## Dependency Security

### React Native Supply Chain Risks
- npm packages can include native code (Objective-C, Java/Kotlin)
- A malicious native module has full device access (filesystem, network, cameras)
- Expo config plugins modify native code at build time

### Mitigation
- Pin exact versions in `package.json` (not `^` ranges) for native modules
- Review native module permissions before adding
- Use only well-maintained packages with large user bases
- Run `npx expo-doctor` to check for known issues
- Keep Expo SDK updated — security patches ship with SDK updates

---

## Incident Response on Mobile

### You Can't Hotfix a Deployed Binary
This is the biggest mental shift from web/cloud. If a security issue is in native code:
1. Fix the code
2. Build new binary (`eas build`)
3. Submit to App Store / Play Store (1-3 day review)
4. Users must update (or you force-update)

### What You CAN Hotfix via OTA
- JS-only vulnerabilities (logic bugs, missing validation)
- Configuration changes
- Feature flags (disable a vulnerable feature)

### Emergency Playbook
1. **Immediate:** Disable affected API endpoints server-side (Lambda/API Gateway)
2. **If JS-fixable:** Push OTA update via EAS Update (takes effect on next app launch)
3. **If native-fixable:** Expedited review (Apple supports this for critical fixes)
4. **Kill sessions:** Revoke all Clerk sessions via Clerk Dashboard (forces re-auth)
5. **Communicate:** In-app banner on next open explaining the issue

### Force Update Mechanism
```typescript
// Server returns minimum required version
// App checks on launch and blocks if outdated
const { minVersion } = await api.getConfig();
if (semverLt(currentVersion, minVersion)) {
  showForceUpdateScreen(); // Only shows "Update" button, no dismiss
}
```

---

## Security Checklist for Iduna

### MVP (Must Have)
- [ ] Clerk tokens in expo-secure-store (not AsyncStorage)
- [ ] No secrets in JS bundle (only `EXPO_PUBLIC_` prefixed vars)
- [ ] Logout clears all local data (Keychain, AsyncStorage, SQLite)
- [ ] API validates Clerk JWT on every request (server-side, not client)
- [ ] HTTPS enforced (default on both platforms)
- [ ] Input validation in Lambda (Pydantic models)
- [ ] Privacy policy covering health data
- [ ] Data deletion endpoint (GDPR Art. 17)
- [ ] Medical disclaimer in app

### Post-MVP (Should Have)
- [ ] Biometric re-auth for sensitive operations
- [ ] Force-update mechanism for critical security fixes
- [ ] Rate limiting on API (already have WAF)
- [ ] Sentry for crash reporting (no PII in breadcrumbs)
- [ ] Review native dependencies quarterly for vulnerabilities
