---
name: app-store-publishing
description: App Store and Play Store publishing for React Native + Expo apps. Covers review processes, health app requirements, EAS Build/Submit, IAP with RevenueCat, versioning, OTA updates, and launch checklists.
---

# App Store & Play Store Publishing

## Platform Comparison

| | Apple App Store | Google Play Store |
|---|---|---|
| **Developer account** | $99/year | $25 one-time |
| **Review time** | 1-3 days (health apps: 2-5 days) | 1-3 days (first app: up to 7 days) |
| **Commission** | 30% (15% under Small Business Program <$1M/yr) | 30% (15% under $1M/yr) |
| **IAP required** | Yes, for digital goods/services consumed in-app | Yes, for digital goods/services |
| **External payment links** | Allowed in US (StoreKit External Links Entitlement, Apple still charges commission on tracked purchases) | Allowed with User Choice Billing (Play charges reduced commission) |
| **Beta testing** | TestFlight (up to 10,000 testers) | Internal/Closed/Open testing tracks |
| **Staged rollout** | Phased release (1-100% over 7 days) | Staged rollout (0.1-100%) |
| **OTA updates** | Allowed for JS bundles (no behavior change) | Allowed |

---

## When IAP Is Required vs. Optional

### MUST use In-App Purchase (Apple & Google)
- Subscription to app features (premium tier, drift predictions)
- One-time unlock of features
- Consumable digital goods
- Any "digital content consumed within the app"

### CAN use External Payments
- **Physical goods/services** — Not applicable to Iduna
- **Reader app exemption** — Apps whose primary purpose is accessing previously purchased content (Netflix, Kindle). Not applicable.
- **Web-initiated subscriptions** — If user subscribes on your website BEFORE downloading the app, you can unlock features without IAP. This is the Lemon Squeezy path for Iduna.

### Iduna Payment Strategy
- **Mobile:** RevenueCat for IAP subscriptions (Apple/Google get their cut)
- **Web:** Lemon Squeezy (no platform commission)
- **Cross-platform:** RevenueCat + Lemon Squeezy both write to a shared subscription status. Server checks both when validating entitlements.

---

## EAS Build + Submit

### Build Profiles (eas.json)
```json
{
  "cli": { "version": ">= 12.0.0" },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "env": { "EXPO_PUBLIC_API_URL": "http://localhost:3000" }
    },
    "preview": {
      "distribution": "internal",
      "channel": "preview",
      "env": { "EXPO_PUBLIC_API_URL": "https://dev-api.iduna.app" }
    },
    "production": {
      "channel": "production",
      "autoIncrement": true,
      "env": { "EXPO_PUBLIC_API_URL": "https://api.iduna.app" }
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleId": "scott@iduna.app",
        "ascAppId": "1234567890",
        "appleTeamId": "XXXXXXXXXX"
      },
      "android": {
        "serviceAccountKeyPath": "./play-store-key.json",
        "track": "internal"
      }
    }
  }
}
```

### Build Commands
```bash
# Development build (dev client, replaces Expo Go)
eas build --profile development --platform ios

# Preview build for testing (TestFlight/internal testing)
eas build --profile preview --platform all

# Production build
eas build --profile production --platform all

# Submit to stores
eas submit --platform ios --profile production
eas submit --platform android --profile production

# One command: build + submit
eas build --profile production --platform all --auto-submit
```

### App Signing

**iOS:**
- EAS manages certificates and provisioning profiles automatically
- On first build, EAS creates: Distribution Certificate + Provisioning Profile
- Stored in EAS servers (encrypted). You can also use local credentials.
- **Don't lose your distribution certificate** — needed for all future builds

**Android:**
- EAS generates an upload key on first build
- Google Play App Signing manages the actual signing key
- Upload key → Google re-signs with their key
- If you lose the upload key, Google can reset it (unlike Apple)

---

## App Store Review — Health App Specifics

### Common Rejection Reasons for Health Apps

1. **Insufficient HealthKit usage description** — "We need your health data" is rejected. Must explain specifically: "Iduna reads your dietary energy, protein, exercise, and weight data to compare your current patterns against your established baseline and detect behavioral drift."

2. **Medical claims** — NEVER claim to diagnose, treat, or prevent any condition. Iduna must explicitly disclaim: "This app is not a medical device and does not provide medical advice."

3. **Missing privacy policy** — Must be hosted at a public URL, linked in App Store Connect, and cover: what health data you collect, how it's stored, how it's shared (or not), deletion process.

4. **HealthKit data not used meaningfully** — If you request HealthKit access, you must actually use the data in the app's core experience. Reading weight just to display it isn't sufficient — you must add value.

5. **Incomplete demo** — App Review may not have health data to test. Provide demo credentials with pre-populated data, or a "demo mode" that shows the app with sample data.

### App Store Metadata Requirements (iOS)

| Field | Requirement | Iduna Recommendation |
|-------|------------|---------------------|
| Name | ≤30 chars | "Iduna - Drift Tracker" |
| Subtitle | ≤30 chars | "Post-GLP-1 Maintenance" |
| Description | ≤4000 chars | Focus on problem + solution |
| Keywords | ≤100 chars | "glp1,wegovy,ozempic,maintenance,weight,drift,nutrition" |
| Category | Primary + Secondary | Health & Fitness + Lifestyle |
| Screenshots | 6.7" + 6.5" + 5.5" (iPhone), optional iPad | Dashboard, log screen, drift chart, weekly summary, onboarding |
| App Privacy | Data types, usage, linked to identity? | Health, Nutrition, Exercise, Body Measurements, Contact Info (email) |
| Age Rating | Questionnaire | 4+ (no mature content) |
| Support URL | Required | https://iduna.app/support |
| Privacy Policy URL | Required | https://iduna.app/privacy |

### Play Store Requirements (Android)

| Field | Requirement |
|-------|------------|
| Data safety section | Declare all data types collected/shared |
| Content rating | IARC questionnaire |
| Target audience | Specify age range (Adults 18+) |
| Health claims policy | Same as Apple — no medical claims |
| Feature graphic | 1024x500px |
| Screenshots | Min 2, up to 8 per device type |

---

## In-App Purchases with RevenueCat

### Setup
```typescript
// Initialize RevenueCat in app root
import Purchases from 'react-native-purchases';
import { Platform } from 'react-native';

const REVENUECAT_IOS_KEY = process.env.EXPO_PUBLIC_RC_IOS_KEY!;
const REVENUECAT_ANDROID_KEY = process.env.EXPO_PUBLIC_RC_ANDROID_KEY!;

async function initializePurchases(clerkUserId: string) {
  Purchases.configure({
    apiKey: Platform.OS === 'ios' ? REVENUECAT_IOS_KEY : REVENUECAT_ANDROID_KEY,
    appUserID: clerkUserId, // Link RevenueCat to Clerk user
  });
}
```

### Subscription Flow
```typescript
import Purchases, { PurchasesPackage } from 'react-native-purchases';

async function getOfferings() {
  const offerings = await Purchases.getOfferings();
  return offerings.current?.availablePackages ?? [];
}

async function purchasePackage(pkg: PurchasesPackage) {
  try {
    const { customerInfo } = await Purchases.purchasePackage(pkg);
    const isPremium = customerInfo.entitlements.active['premium'] !== undefined;
    return isPremium;
  } catch (e: any) {
    if (e.userCancelled) return false; // User cancelled — don't show error
    throw e;
  }
}

async function checkEntitlements(): Promise<boolean> {
  const customerInfo = await Purchases.getCustomerInfo();
  return customerInfo.entitlements.active['premium'] !== undefined;
}

async function restorePurchases() {
  const customerInfo = await Purchases.restorePurchases();
  return customerInfo.entitlements.active['premium'] !== undefined;
}
```

### RevenueCat + Lemon Squeezy Coexistence
```
Mobile purchase → RevenueCat → StoreKit/Play Billing → RevenueCat webhook → your server
Web purchase   → Lemon Squeezy → Lemon Squeezy webhook → your server

Your server → writes SUB item to DynamoDB:
  PK: USER#clerk_abc
  SK: SUB
  tier: "premium"
  source: "revenuecat" | "lemonsqueezy"
  expiresAt: "2027-06-15T..."
  status: "active"
```

Both webhooks write to the same `SUB` item. App checks entitlement on launch by reading the `SUB` item (cached locally).

---

## Versioning Strategy

### Version Numbers
```json
// app.json / app.config.ts
{
  "version": "1.2.0",        // User-visible (semver)
  "ios": {
    "buildNumber": "42"       // Must increment for each App Store upload
  },
  "android": {
    "versionCode": 42          // Must increment, integer only
  }
}
```

With `"autoIncrement": true` in `eas.json`, EAS increments build numbers automatically.

### Forced Updates for Breaking API Changes
```typescript
// Check minimum app version on launch
const MIN_VERSION = '1.2.0'; // Set by server config or hardcoded

import * as Application from 'expo-application';
import { Linking, Alert } from 'react-native';

function checkForceUpdate() {
  const currentVersion = Application.nativeApplicationVersion;
  if (currentVersion && semverLt(currentVersion, MIN_VERSION)) {
    Alert.alert(
      'Update Required',
      'A new version of Iduna is available. Please update to continue.',
      [{
        text: 'Update',
        onPress: () => {
          const storeUrl = Platform.OS === 'ios'
            ? 'itms-apps://apps.apple.com/app/iduna/id1234567890'
            : 'market://details?id=com.iduna.app';
          Linking.openURL(storeUrl);
        },
      }],
      { cancelable: false }
    );
  }
}
```

---

## OTA Updates (EAS Update)

```bash
# Push JS-only update to production channel
eas update --channel production --message "Fix drift percentage rounding"

# Push to preview channel for testing first
eas update --channel preview --message "Test drift fix"
```

### What OTA CAN Update
- JavaScript/TypeScript code changes
- Asset changes (images, fonts bundled in JS)
- Configuration changes in JS

### What OTA CANNOT Update (Requires New Binary)
- Native module changes (adding a new Expo module)
- Expo SDK version upgrade
- iOS/Android config changes (permissions, entitlements)
- Native dependency version changes

### Apple's Rules on OTA
- You CAN update JS bundles
- You CANNOT materially change the app's behavior or purpose
- You CANNOT bypass App Review for new features
- Bug fixes and minor improvements are explicitly allowed

---

## Launch Checklist

### Pre-submission (Both Platforms)
- [ ] Privacy policy hosted at public URL
- [ ] Support email/URL configured
- [ ] App icon (1024x1024 for iOS, 512x512 for Android)
- [ ] Screenshots for all required device sizes
- [ ] Test with production API endpoints
- [ ] Remove all debug logging and dev-only features
- [ ] Verify crash reporting (Sentry) is connected
- [ ] Medical disclaimer visible in app (Settings or About)
- [ ] GDPR consent flow works (if applicable)
- [ ] Test in-app purchases in sandbox environment
- [ ] "Restore Purchases" button exists and works

### iOS Specific
- [ ] Apple Developer Program membership active ($99/yr)
- [ ] App Store Connect app record created
- [ ] HealthKit entitlement enabled
- [ ] All Info.plist usage descriptions are specific and clear
- [ ] App Privacy labels completed in App Store Connect
- [ ] TestFlight beta tested with external testers
- [ ] Demo account credentials prepared for App Review

### Android Specific
- [ ] Google Play Console account created ($25 one-time)
- [ ] DUNS number for organization (if publishing as org)
- [ ] Health Connect permissions declared in AndroidManifest
- [ ] Data Safety section completed
- [ ] Content rating questionnaire completed
- [ ] Internal testing track tested
- [ ] Feature graphic (1024x500) uploaded

### Post-Launch
- [ ] Monitor crash-free rate (target: >99.5%)
- [ ] Monitor App Store / Play Store reviews (respond within 24hr)
- [ ] Set up alerting for revenue drops (RevenueCat webhook)
- [ ] Plan first update within 2 weeks (shows active development)

---

## Common Pitfalls

1. **First iOS submission takes longest** — 3-7 days for health apps. Plan accordingly.
2. **Forgetting to test IAP in sandbox** — StoreKit sandbox (iOS) and test tracks (Android) behave differently from production.
3. **Screenshots must match current build** — Apple rejects if screenshots show features that don't exist in the submitted binary.
4. **Auto-renewal disclosure** — Apple requires clear language about subscription pricing, period, and auto-renewal in the paywall UI. This is a common rejection reason.
5. **"Restore Purchases" must be visible** — Both platforms require a restore button. Missing it = rejection.
6. **Not having a web fallback for health data** — If HealthKit is denied, your app must still be useful (manual logging). Apple rejects apps that are "broken" without optional permissions.
7. **Pricing across platforms** — Apple rounds prices to "price points" ($0.99, $1.99, etc.). Plan your pricing to work with both Apple's price tiers and Lemon Squeezy's flexible pricing.
