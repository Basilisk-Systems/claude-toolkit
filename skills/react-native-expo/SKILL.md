---
name: react-native-expo
description: React Native + Expo patterns for managed workflow apps. Use when building mobile UI, navigation, performance optimization, or debugging RN apps.
---

# React Native + Expo Patterns

## Tech Stack
- **Framework**: React Native 0.76+ (New Architecture default)
- **Platform**: Expo SDK 52+ (managed workflow, EAS Build)
- **Engine**: Hermes (default, compiles JS to bytecode AOT)
- **Navigation**: Expo Router v4 (file-based, built on React Navigation)
- **Styling**: NativeWind v4 (Tailwind for RN) or StyleSheet
- **Testing**: Jest + React Native Testing Library, Detox for E2E
- **Build**: EAS Build (cloud) or local with `npx expo run:ios/android`

---

## Key Differences from Web React

### No DOM — Everything is Native Views
```typescript
// WEB (won't work in RN)
<div className="container">
  <span>Text here</span>
  <p onClick={handler}>Click me</p>
</div>

// REACT NATIVE
import { View, Text, Pressable } from 'react-native';

<View style={styles.container}>
  <Text>Text here</Text>
  <Pressable onPress={handler}>
    <Text>Press me</Text>
  </Pressable>
</View>
```

**Critical gotchas for web developers:**
- All text MUST be inside `<Text>` — bare strings crash the app
- No CSS inheritance except within nested `<Text>` components
- No `onClick` — use `onPress` (Pressable, TouchableOpacity)
- No `className` without NativeWind — use `style` prop with StyleSheet
- No CSS Grid. Flexbox is default and `flexDirection` defaults to `column` (not `row`)
- No `hover` states — mobile has press states, not hover
- No `window`, `document`, `localStorage`, `fetch` polyfill needed for some APIs
- `position: 'fixed'` doesn't exist — use `position: 'absolute'` within a full-screen container

### StyleSheet vs NativeWind

```typescript
// StyleSheet (native, zero runtime cost)
import { StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 16,
    backgroundColor: '#fff',
  },
  title: {
    fontSize: 24,
    fontWeight: '600',
    color: '#1a1a1a',
  },
});

// NativeWind (Tailwind syntax, compiles to StyleSheet at build time)
<View className="flex-1 p-4 bg-white">
  <Text className="text-2xl font-semibold text-gray-900">Title</Text>
</View>
```

**NativeWind recommendation:** Use it. Familiar if you know Tailwind, zero runtime overhead (compiles at build), and shares utility classes with web if using Turborepo shared config.

---

## Project Structure (Expo Router)

```
apps/mobile/
├── app/                        # File-based routes (Expo Router)
│   ├── _layout.tsx            # Root layout (providers, auth gate)
│   ├── (auth)/                # Auth-required group
│   │   ├── _layout.tsx        # Tab navigator layout
│   │   ├── (tabs)/
│   │   │   ├── _layout.tsx    # Tab bar config
│   │   │   ├── index.tsx      # Dashboard tab
│   │   │   ├── log.tsx        # Log tab
│   │   │   ├── history.tsx    # History tab
│   │   │   └── settings.tsx   # Settings tab
│   │   ├── meal/[id].tsx      # Meal detail (stack)
│   │   └── exercise/[id].tsx  # Exercise detail (stack)
│   ├── (public)/              # No auth required
│   │   ├── sign-in.tsx
│   │   └── onboarding.tsx
│   └── +not-found.tsx         # 404
├── components/                 # Shared components
├── hooks/                      # Custom hooks
├── lib/                        # Utilities, API client, sync
├── stores/                     # State management
├── constants/                  # Colors, spacing, config
├── app.json                    # Expo config
├── eas.json                    # EAS Build profiles
├── metro.config.js             # Metro bundler config
├── tailwind.config.ts          # NativeWind config
└── tsconfig.json
```

### Route Groups and Layouts

```typescript
// app/_layout.tsx — Root layout with providers
import { Stack } from 'expo-router';
import { ClerkProvider } from '@clerk/clerk-expo';

export default function RootLayout() {
  return (
    <ClerkProvider publishableKey={process.env.EXPO_PUBLIC_CLERK_KEY!}>
      <Stack screenOptions={{ headerShown: false }}>
        <Stack.Screen name="(public)" />
        <Stack.Screen name="(auth)" />
      </Stack>
    </ClerkProvider>
  );
}

// app/(auth)/_layout.tsx — Auth gate
import { Redirect } from 'expo-router';
import { useAuth } from '@clerk/clerk-expo';

export default function AuthLayout() {
  const { isSignedIn, isLoaded } = useAuth();
  if (!isLoaded) return <LoadingScreen />;
  if (!isSignedIn) return <Redirect href="/sign-in" />;
  return <Stack />;
}

// app/(auth)/(tabs)/_layout.tsx — Tab navigator
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';

export default function TabLayout() {
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: '#2563eb' }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'Dashboard',
          tabBarIcon: ({ color, size }) => (
            <Ionicons name="stats-chart" size={size} color={color} />
          ),
        }}
      />
      <Tabs.Screen name="log" options={{ title: 'Log' }} />
      <Tabs.Screen name="history" options={{ title: 'History' }} />
      <Tabs.Screen name="settings" options={{ title: 'Settings' }} />
    </Tabs>
  );
}
```

---

## Navigation Patterns

### Deep Linking from Notifications
```typescript
// Expo Router uses URL-based routing, so deep links map naturally
// Notification payload: { data: { url: '/meal/abc123' } }
import * as Notifications from 'expo-notifications';
import { router } from 'expo-router';

Notifications.addNotificationResponseReceivedListener((response) => {
  const url = response.notification.request.content.data?.url;
  if (url) router.push(url);
});
```

### Typed Navigation
```typescript
// Expo Router v4 generates types from your file structure
import { router } from 'expo-router';

router.push('/meal/abc123');          // Type-checked route
router.push({ pathname: '/meal/[id]', params: { id: 'abc123' } });
router.back();                         // Pop stack
router.replace('/sign-in');            // Replace (no back)
```

---

## Performance

### Hermes Engine
- Default since Expo SDK 48, mandatory in SDK 52+
- Compiles JS to bytecode at build time (not JIT) — faster cold start
- Lower memory usage than JSC
- Supports `Intl` natively (no polyfill needed)
- **Debugging:** Use Chrome DevTools via `j` in Expo CLI, or React Native DevTools

### Lists — The #1 Performance Concern
```typescript
// BAD: renders all items at once
import { ScrollView } from 'react-native';
items.map(item => <MealCard key={item.id} meal={item} />)

// GOOD: virtualizes off-screen items
import { FlashList } from '@shopify/flash-list';

<FlashList
  data={meals}
  renderItem={({ item }) => <MealCard meal={item} />}
  estimatedItemSize={80}  // Required — measure your actual item height
  keyExtractor={(item) => item.id}
/>
```

**FlashList vs FlatList:**
- FlashList (by Shopify): recycles cells like UITableView/RecyclerView. Use this.
- FlatList: built-in but creates/destroys cells. Fine for <50 items.
- For Iduna's meal history (~6 items/day, paginated): FlashList for the main list, FlatList for short lists.

### Memoization — Different from Web
```typescript
// In RN, re-renders are expensive because they cross the JS-to-native bridge
// Memoize list items aggressively

const MealCard = React.memo(function MealCard({ meal }: { meal: Meal }) {
  return (
    <View>
      <Text>{meal.name}</Text>
      <Text>{meal.calories} cal</Text>
    </View>
  );
});

// Stable callbacks for list items
const handlePress = useCallback((id: string) => {
  router.push(`/meal/${id}`);
}, []);
```

### Images
```typescript
// Use expo-image, NOT React Native's <Image>
import { Image } from 'expo-image';

<Image
  source={{ uri: imageUrl }}
  style={{ width: 100, height: 100 }}
  contentFit="cover"
  placeholder={{ blurhash: 'LEHV6nWB2yk8' }}  // Instant placeholder
  transition={200}
  cachePolicy="memory-disk"  // Automatic caching
/>
```

### New Architecture (Fabric + TurboModules)
- Default since RN 0.76 / Expo SDK 52
- Eliminates the async bridge — synchronous JS-to-native calls
- Fabric: new rendering system (concurrent features work)
- TurboModules: lazy-loaded native modules (faster startup)
- **You don't need to do anything special** — Expo manages this

---

## State Management

### Zustand (Recommended for Iduna)
```typescript
// Lightweight, no boilerplate, works perfectly with RN
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

interface SyncStore {
  lastSyncedAt: string | null;
  pendingChanges: number;
  isSyncing: boolean;
  sync: () => Promise<void>;
}

const useSyncStore = create<SyncStore>()(
  persist(
    (set, get) => ({
      lastSyncedAt: null,
      pendingChanges: 0,
      isSyncing: false,
      sync: async () => {
        set({ isSyncing: true });
        // ... sync logic
        set({ isSyncing: false, lastSyncedAt: new Date().toISOString() });
      },
    }),
    {
      name: 'sync-store',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
```

### App State (Unique to Mobile)
```typescript
// Mobile apps have foreground/background/inactive states — web doesn't
import { AppState, AppStateStatus } from 'react-native';
import { useEffect, useRef } from 'react';

function useAppStateSync() {
  const appState = useRef(AppState.currentState);

  useEffect(() => {
    const sub = AppState.addEventListener('change', (nextState: AppStateStatus) => {
      if (appState.current.match(/inactive|background/) && nextState === 'active') {
        // App returned to foreground — trigger sync
        useSyncStore.getState().sync();
      }
      appState.current = nextState;
    });
    return () => sub.remove();
  }, []);
}
```

---

## Testing

### Unit/Component Tests (Jest + RNTL)
```typescript
import { render, screen, fireEvent } from '@testing-library/react-native';
import { MealCard } from './MealCard';

test('displays meal calories', () => {
  render(<MealCard meal={{ id: '1', name: 'Lunch', calories: 650 }} />);
  expect(screen.getByText('650 cal')).toBeTruthy();
});

test('calls onPress with meal id', () => {
  const onPress = jest.fn();
  render(<MealCard meal={testMeal} onPress={onPress} />);
  fireEvent.press(screen.getByText('Lunch'));
  expect(onPress).toHaveBeenCalledWith('1');
});
```

### E2E Tests (Detox)
```typescript
// Detox runs on real simulator/emulator — tests actual native behavior
describe('Meal Logging', () => {
  it('should add a meal from the log screen', async () => {
    await element(by.id('tab-log')).tap();
    await element(by.id('quick-add-button')).tap();
    await element(by.id('meal-name-input')).typeText('Grilled chicken');
    await element(by.id('calories-input')).typeText('450');
    await element(by.id('save-button')).tap();
    await expect(element(by.text('Grilled chicken'))).toBeVisible();
  });
});
```

**Testing gotchas:**
- Push notifications can't be tested on iOS simulator — must use physical device or EAS Build
- HealthKit requires physical device with Health app
- Expo Go has limitations — use dev client (`npx expo run:ios`) for native module testing
- `jest.useFakeTimers()` can break Reanimated animations — use `jest.advanceTimersByTime()`

---

## Debugging

### Tools (Flipper is deprecated)
1. **React Native DevTools** — `j` in Expo CLI terminal, opens Chrome DevTools for JS debugging
2. **React DevTools** — Component tree, props/state inspection: `npx react-devtools`
3. **Expo Dev Client** — Shake device or Cmd+D for dev menu (network inspector, performance overlay)
4. **LogBox** — In-app error/warning overlay. Suppress known warnings:
   ```typescript
   import { LogBox } from 'react-native';
   LogBox.ignoreLogs(['Warning: ...']); // Suppress specific warnings
   ```
5. **Reactotron** — Desktop app for inspecting state, API calls, async storage

### Common Pitfalls
- **"Text strings must be rendered within a <Text> component"** — Bare string outside `<Text>`
- **VirtualizedList nesting warning** — Don't put FlatList inside ScrollView. Use FlatList's `ListHeaderComponent`/`ListFooterComponent` instead
- **Keyboard covers input** — Use `KeyboardAvoidingView` with `behavior="padding"` (iOS) or `"height"` (Android)
- **Metro bundler cache** — If weird behavior after dependency changes: `npx expo start --clear`
- **"Unable to resolve module"** — Restart Metro, clear watchman: `watchman watch-del-all`

---

## EAS Build Configuration

```json
// eas.json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "ios": { "simulator": true }
    },
    "preview": {
      "distribution": "internal",
      "ios": { "simulator": false }
    },
    "production": {
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": { "appleId": "...", "ascAppId": "...", "appleTeamId": "..." },
      "android": { "serviceAccountKeyPath": "./google-services.json" }
    }
  }
}
```

### Build Profiles
- `development` — Dev client for local development (replaces Expo Go for native modules)
- `preview` — Internal distribution for testing (TestFlight-like)
- `production` — App Store / Play Store submission

### OTA Updates (EAS Update)
```bash
# Push JS-only changes without App Store review
eas update --branch production --message "Fix drift calculation rounding"
```
- Only updates JS bundle — native code changes require new binary build
- Apple allows this as long as you don't materially change app behavior
- Use `expo-updates` to check/apply updates on app launch

---

## Expo Config (app.json / app.config.ts)

```typescript
// app.config.ts — dynamic config for environment-specific values
import { ExpoConfig, ConfigContext } from 'expo/config';

export default ({ config }: ConfigContext): ExpoConfig => ({
  ...config,
  name: 'Iduna',
  slug: 'iduna',
  version: '1.0.0',
  orientation: 'portrait',
  icon: './assets/icon.png',
  splash: { image: './assets/splash.png', resizeMode: 'contain' },
  ios: {
    bundleIdentifier: 'com.iduna.app',
    supportsTablet: false,
    infoPlist: {
      NSHealthShareUsageDescription: 'Iduna reads your health data to detect drift from your baseline.',
      NSHealthUpdateUsageDescription: 'Iduna does not write to Apple Health.',
    },
  },
  android: {
    package: 'com.iduna.app',
    adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png' },
  },
  plugins: [
    'expo-router',
    'expo-secure-store',
    ['expo-notifications', { icon: './assets/notification-icon.png' }],
  ],
  extra: {
    eas: { projectId: 'your-project-id' },
    clerkPublishableKey: process.env.EXPO_PUBLIC_CLERK_KEY,
  },
});
```
