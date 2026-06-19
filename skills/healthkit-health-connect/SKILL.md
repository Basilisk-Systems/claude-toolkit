---
name: healthkit-health-connect
description: Apple HealthKit and Android Health Connect integration for React Native + Expo apps. Covers data reading, permissions, background sync, nutrition/exercise/weight specifics, and import deduplication.
---

# HealthKit & Health Connect Integration

## Overview

| | Apple HealthKit | Android Health Connect |
|---|---|---|
| **API** | Objective-C/Swift framework | Jetpack library (Kotlin) |
| **RN Library** | `react-native-health` | `react-native-health-connect` |
| **Expo** | Needs config plugin + dev client (not Expo Go) | Needs config plugin + dev client |
| **Background sync** | Yes (observer queries, min ~1hr) | No — foreground only |
| **Permission model** | Per-type, can't check if granted | Per-type, can check if granted |
| **Data stays on device** | Yes (unless explicitly shared) | Yes (unless explicitly shared) |

---

## React Native Libraries

### Installation (Expo Managed Workflow)
```bash
# HealthKit (iOS)
npx expo install react-native-health
# Requires config plugin in app.config.ts

# Health Connect (Android)
npx expo install react-native-health-connect
# Requires config plugin in app.config.ts
```

Both require **Expo Dev Client** (not Expo Go) because they include native modules.

### Expo Config
```typescript
// app.config.ts
export default {
  plugins: [
    // HealthKit
    [
      'react-native-health',
      {
        isClinicalDataEnabled: false,
      },
    ],
    // Health Connect
    [
      'react-native-health-connect',
      {
        healthPermissions: [
          'NutritionRecord',
          'ExerciseSessionRecord',
          'WeightRecord',
        ],
      },
    ],
  ],
  ios: {
    infoPlist: {
      NSHealthShareUsageDescription:
        'Iduna reads your nutrition, exercise, and weight data to detect drift from your baseline patterns.',
    },
  },
};
```

---

## Permission Patterns

### HealthKit Permissions — The Privacy Trap

**Critical:** HealthKit NEVER tells you if the user denied a specific type. `authorizationStatus` returns:
- `notDetermined` — Never asked
- `sharingAuthorized` — Write access granted (only relevant if writing)
- `sharingDenied` — Write access denied

For **read** access, the API returns `notDetermined` whether the user granted OR denied. This is by design — Apple doesn't want apps to know what health data a user has.

**Practical implication:** You request permission, the user denies "Dietary Energy", and your query returns zero results. You cannot distinguish "no data" from "permission denied." Design your UI accordingly.

```typescript
import AppleHealthKit, {
  HealthKitPermissions,
  HealthPermission,
} from 'react-native-health';

const permissions: HealthKitPermissions = {
  permissions: {
    read: [
      AppleHealthKit.Constants.Permissions.DietaryEnergy,      // Calories
      AppleHealthKit.Constants.Permissions.DietaryProtein,      // Protein
      AppleHealthKit.Constants.Permissions.Workout,             // Exercise
      AppleHealthKit.Constants.Permissions.BodyMass,            // Weight
      AppleHealthKit.Constants.Permissions.DietaryCarbohydrates,
      AppleHealthKit.Constants.Permissions.DietaryFatTotal,
    ],
    write: [], // Iduna is read-only
  },
};

function requestHealthKitPermission(): Promise<boolean> {
  return new Promise((resolve) => {
    AppleHealthKit.initHealthKit(permissions, (err) => {
      if (err) {
        console.error('HealthKit init failed:', err);
        resolve(false);
        return;
      }
      resolve(true);
    });
  });
}
```

### Health Connect Permissions
```typescript
import {
  initialize,
  requestPermission,
  readRecords,
} from 'react-native-health-connect';

async function requestHealthConnectPermission(): Promise<boolean> {
  const isInitialized = await initialize();
  if (!isInitialized) return false;

  const granted = await requestPermission([
    { accessType: 'read', recordType: 'NutritionRecord' },
    { accessType: 'read', recordType: 'ExerciseSessionRecord' },
    { accessType: 'read', recordType: 'WeightRecord' },
  ]);

  // Unlike HealthKit, Health Connect tells you what was granted
  return granted.length > 0;
}
```

### When to Ask (UX Pattern)

1. **Not on first launch.** Not even on onboarding.
2. Show health import as an optional feature: "Import from Apple Health / Health Connect"
3. When user taps "Connect", show a pre-permission screen explaining exactly what you'll read and why
4. Then trigger the system permission dialog
5. If partially granted (weight yes, nutrition no), work with what you get — don't block

---

## Reading Nutrition Data

### HealthKit: Dietary Energy (Calories)

```typescript
import AppleHealthKit, { HealthValue } from 'react-native-health';

interface NutritionEntry {
  calories: number;
  protein?: number;
  date: string;        // Local date for DynamoDB SK
  sourceApp: string;
  sourceId: string;    // For dedup
  mealType?: string;
  startDate: string;   // ISO UTC
  endDate: string;     // ISO UTC
}

function getCalories(startDate: Date, endDate: Date): Promise<NutritionEntry[]> {
  return new Promise((resolve, reject) => {
    AppleHealthKit.getDietaryEnergySamples(
      {
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        ascending: true,
        limit: 0, // No limit
      },
      (err, results: HealthValue[]) => {
        if (err) { reject(err); return; }
        const entries = results.map((sample) => ({
          calories: sample.value,
          date: extractLocalDate(sample.startDate, sample.metadata?.HKTimeZone),
          sourceApp: sample.sourceName,
          sourceId: sample.id,  // UUID for dedup
          mealType: mapHealthKitMealType(sample.metadata?.HKFoodMeal),
          startDate: sample.startDate,
          endDate: sample.endDate,
        }));
        resolve(entries);
      }
    );
  });
}
```

### HealthKit Meal Type Mapping

HealthKit uses `HKMetadataKeyFoodType` or the meal correlation type. However, **not all apps write meal type metadata.** MyFitnessPal does. Lose It does. Many don't.

```typescript
function mapHealthKitMealType(hkMealType?: number): string {
  // HKMetadataKeyFoodType values (not officially documented, varies by source app)
  switch (hkMealType) {
    case 1: return 'Breakfast';
    case 2: return 'Lunch';
    case 3: return 'Dinner';
    case 4: return 'Snack';
    default: return 'Uncategorized';
  }
}
```

### HealthKit Workouts (Exercise)

```typescript
function getWorkouts(startDate: Date, endDate: Date): Promise<ExerciseEntry[]> {
  return new Promise((resolve, reject) => {
    AppleHealthKit.getSamples(
      {
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        type: 'Workout',
      },
      (err, results) => {
        if (err) { reject(err); return; }
        const entries = results.map((workout) => ({
          type: mapWorkoutType(workout.activityName),
          category: categorizeExercise(workout.activityName),
          durationMinutes: workout.duration,  // In minutes
          caloriesBurned: workout.calories,
          date: extractLocalDate(workout.startDate, workout.metadata?.HKTimeZone),
          sourceApp: workout.sourceName,
          sourceId: workout.id,
          startDate: workout.startDate,
          endDate: workout.endDate,
        }));
        resolve(entries);
      }
    );
  });
}

function categorizeExercise(activityName: string): string {
  const cardio = ['Running', 'Cycling', 'Swimming', 'Walking', 'Hiking', 'Rowing', 'Elliptical', 'StairClimbing'];
  const strength = ['TraditionalStrengthTraining', 'FunctionalStrengthTraining', 'CrossTraining'];
  if (cardio.includes(activityName)) return 'Cardio';
  if (strength.includes(activityName)) return 'Strength';
  return 'Other';
}
```

### Health Connect: Nutrition Records

```typescript
import { readRecords } from 'react-native-health-connect';

async function getNutritionRecords(startDate: Date, endDate: Date) {
  const result = await readRecords('NutritionRecord', {
    timeRangeFilter: {
      operator: 'between',
      startTime: startDate.toISOString(),
      endTime: endDate.toISOString(),
    },
  });

  return result.records.map((record) => ({
    calories: record.energy?.inKilocalories ?? 0,
    protein: record.protein?.inGrams,
    date: extractLocalDateFromOffset(record.startTime, record.startZoneOffset),
    sourceApp: record.metadata?.dataOrigin ?? 'unknown',
    sourceId: record.metadata?.id ?? '',
    mealType: mapHealthConnectMealType(record.mealType),
  }));
}

function mapHealthConnectMealType(mealType?: number): string {
  // Health Connect MealType enum
  switch (mealType) {
    case 1: return 'Breakfast';
    case 2: return 'Lunch';
    case 3: return 'Dinner';
    case 4: return 'Snack';
    default: return 'Uncategorized';
  }
}
```

### Weight Data

```typescript
// HealthKit
function getWeight(startDate: Date, endDate: Date): Promise<WeightEntry[]> {
  return new Promise((resolve, reject) => {
    AppleHealthKit.getWeightSamples(
      { startDate: startDate.toISOString(), endDate: endDate.toISOString(), unit: 'kg' },
      (err, results) => {
        if (err) { reject(err); return; }
        resolve(results.map((s) => ({
          weightKg: s.value,
          date: extractLocalDate(s.startDate, s.metadata?.HKTimeZone),
          sourceId: s.id,
        })));
      }
    );
  });
}

// Health Connect
async function getWeightRecords(startDate: Date, endDate: Date) {
  const result = await readRecords('WeightRecord', {
    timeRangeFilter: { operator: 'between', startTime: startDate.toISOString(), endTime: endDate.toISOString() },
  });
  return result.records.map((r) => ({
    weightKg: r.weight.inKilograms,
    date: extractLocalDateFromOffset(r.time, r.zoneOffset),
    sourceId: r.metadata?.id ?? '',
  }));
}
```

---

## Timezone Handling for Imports

```typescript
// HealthKit provides HKTimeZone in metadata (iOS 16+)
function extractLocalDate(isoUtcDate: string, timeZone?: string): string {
  if (timeZone) {
    // Use the timezone the data was recorded in
    const dt = new Date(isoUtcDate);
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric', month: '2-digit', day: '2-digit',
    });
    return formatter.format(dt); // "2026-06-15"
  }
  // Fallback: use user's current timezone from PROFILE
  // This is imperfect for historical data during travel, but acceptable for MVP
  return new Date(isoUtcDate).toISOString().split('T')[0];
}

// Health Connect provides ZoneOffset on each record
function extractLocalDateFromOffset(isoTime: string, zoneOffset?: string): string {
  if (zoneOffset) {
    // zoneOffset is like "+05:30" or "-08:00"
    // The record's time is already in UTC; apply offset to get local
    const dt = new Date(isoTime);
    const [hours, minutes] = zoneOffset.replace(/[+-]/, '').split(':').map(Number);
    const sign = zoneOffset.startsWith('-') ? -1 : 1;
    const offsetMs = sign * (hours * 60 + minutes) * 60 * 1000;
    const local = new Date(dt.getTime() + offsetMs);
    return local.toISOString().split('T')[0];
  }
  return new Date(isoTime).toISOString().split('T')[0];
}
```

---

## Import Deduplication

Every HealthKit sample and Health Connect record has a unique ID. Use `source` + `source_id` in DynamoDB to prevent duplicate imports.

```typescript
// Before writing to DynamoDB via sync endpoint
function prepareForSync(entries: NutritionEntry[]): SyncPayload[] {
  return entries.map((entry) => ({
    // DynamoDB item
    type: 'MEAL',
    date: entry.date,
    calories: entry.calories,
    protein: entry.protein,
    mealType: entry.mealType,
    source: entry.sourceApp,           // "MyFitnessPal", "Apple Health"
    sourceId: entry.sourceId,          // UUID from HealthKit/HC
    // Server uses source + sourceId for idempotent upsert
    // If same sourceId exists, update instead of creating duplicate
  }));
}
```

Server-side dedup in the sync Lambda:
```python
# In sync Lambda — check for existing import
existing = table.query(
    KeyConditionExpression="PK = :pk AND begins_with(SK, :prefix)",
    FilterExpression="source_id = :sid",
    ExpressionAttributeValues={
        ":pk": f"USER#{user_id}",
        ":prefix": f"MEAL#{date}",
        ":sid": source_id,
    },
)
if existing["Items"]:
    # Update existing rather than creating duplicate
    update_item(existing["Items"][0], new_data)
else:
    # Create new item with ULID
    put_item(new_meal_item)
```

---

## Background Sync

### iOS (HealthKit Observer Queries)
HealthKit can wake your app when new data is written, even in background.

```typescript
// Register background observer (call once, persists across app restarts)
AppleHealthKit.enableBackgroundDelivery(
  AppleHealthKit.Constants.Permissions.DietaryEnergy,
  AppleHealthKit.Constants.ObserverUpdateFrequency.Hour, // Minimum interval
  (err) => {
    if (err) console.error('Background delivery registration failed:', err);
  }
);
```

**Limitations:**
- Minimum interval: ~1 hour (Apple controls actual timing)
- App gets ~30 seconds of background execution time
- Must re-register on each app launch
- iOS may throttle if your app uses too much background CPU

### Android (No Background Sync)
Health Connect has **no background delivery mechanism.** Your options:
1. **Sync on app launch** — Query for new records since last sync
2. **WorkManager** — Schedule periodic foreground work (Android only, requires Expo config plugin)
3. **Manual sync button** — User-triggered "Import from Health Connect"

**Recommended for Iduna:** Sync on app launch + manual sync button. This covers 95% of use cases since users open the app daily.

---

## App Store / Play Store Requirements

### Apple (HealthKit)
- **Info.plist keys required:**
  - `NSHealthShareUsageDescription` — Explain what you read and why
  - `NSHealthUpdateUsageDescription` — Required even if not writing (can be "Iduna does not write to Apple Health")
- **App Review scrutiny:** Apple manually reviews HealthKit apps. Expect 2-5 day review (vs 1-2 for non-health apps)
- **HealthKit entitlement** — Must enable in Xcode / EAS build config
- **Privacy nutrition label** — Must declare "Health & Fitness" data collection

### Google (Health Connect)
- **AndroidManifest permissions** — Config plugin handles this
- **Privacy policy** — Must explain health data usage, linked in Play Store listing
- **Data Safety section** — Declare health data types collected
- **Health Connect app must be installed** — Your app should gracefully handle "Health Connect not available"

---

## Common Pitfalls

1. **HealthKit silently returns empty results if denied** — Can't tell "no data" from "permission denied." Show a "No data found — make sure Iduna has access in Settings > Health" message.
2. **Health Connect might not be installed** — Check `await initialize()` and guide user to install it from Play Store.
3. **Not all apps write meal types** — Many nutrition apps only write total calories without meal type metadata. Default to "Uncategorized."
4. **Unit conversion bugs** — HealthKit returns energy in kcal by default but CAN return kJ. Always specify units. Health Connect uses its own unit system.
5. **Duplicate imports on full resync** — Always dedup by `source + sourceId` before writing.
6. **Assuming real-time data** — HealthKit data from other apps may be delayed. MyFitnessPal syncs to HealthKit every ~15 minutes.
7. **Testing requires physical device** — HealthKit doesn't exist on simulators. Health Connect works on emulator but with limited data sources.
8. **Background delivery is unreliable** — Don't rely on it for time-critical features. It's a nice-to-have optimization.
