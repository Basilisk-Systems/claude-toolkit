---
name: mobile-ux-patterns
description: Mobile UX patterns and platform conventions for health/fitness React Native apps. Covers navigation, touch interaction, offline UX, data visualization, accessibility, and health app specific patterns.
---

# Mobile UX Patterns

## Platform Conventions

### iOS vs Android — Where It Matters

| Pattern | iOS (HIG) | Android (Material 3) | Recommendation for Iduna |
|---------|-----------|---------------------|--------------------------|
| Back navigation | Swipe from left edge, no back button | System back button/gesture | Expo Router handles both automatically |
| Bottom tabs | Standard (3-5 tabs) | Standard (3-5 tabs) | Same on both — 4 tabs: Dashboard, Log, History, Settings |
| Action sheet | `ActionSheetIOS` slides up | Bottom sheet (Modal) | Use `@gorhom/bottom-sheet` for both |
| Segmented control | `UISegmentedControl` native look | Chips or tabs | Use Expo's `SegmentedControl` (renders native) |
| Pull-to-refresh | Standard on both | Standard on both | Use `RefreshControl` on scroll/list views |
| Haptics | Taptic Engine (rich) | Basic vibration | `expo-haptics` — use for confirmations (meal saved, alert dismissed) |
| Date picker | Inline or wheel | Calendar or text input | `@react-native-community/datetimepicker` (renders native) |
| Status bar | Light/dark based on theme | Light/dark based on theme | `expo-status-bar` auto-adapts |

### One Design or Two?

For Iduna (solo dev, B2C): **One design that respects platform conventions.** Don't build two separate UIs. Use components that render natively on each platform (date pickers, segmented controls, switches) but keep your custom UI (cards, charts, buttons) consistent across platforms.

---

## Navigation Architecture for Iduna

```
Root
├── (public)
│   ├── Onboarding (stack)
│   └── Sign In (stack)
└── (auth) — requires login
    └── Tabs
        ├── Dashboard (home)
        │   └── Drift Detail (stack push)
        ├── Log
        │   ├── Quick Add (modal)
        │   └── Food Search (stack push)
        ├── History
        │   ├── Meal Detail (stack push)
        │   └── Exercise Detail (stack push)
        └── Settings
            ├── Profile (stack push)
            ├── Baseline (stack push)
            ├── Notifications (stack push)
            ├── Health Import (stack push)
            └── Subscription (stack push)
```

### Tab Bar Best Practices
- **3-5 tabs maximum** — more than 5 creates "More" tab (bad UX)
- **Labels required** — Icons alone are ambiguous. Always include text labels.
- **Active state** — Filled icon + tint color for active, outline icon for inactive
- **Badge for alerts** — Red badge on Dashboard tab when drift alert is unread

---

## Touch Targets and Gestures

### Minimum Sizes
```typescript
// Apple HIG: 44x44pt minimum
// Material Design: 48x48dp minimum
// These are LARGER than typical web click targets

// Bad: tiny tap target
<Pressable style={{ padding: 4 }}>
  <Text style={{ fontSize: 12 }}>Delete</Text>
</Pressable>

// Good: adequate tap target with visual padding
<Pressable
  style={{ padding: 12, minHeight: 44, minWidth: 44, justifyContent: 'center' }}
  hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} // Extends tappable area beyond visual bounds
>
  <Text style={{ fontSize: 14 }}>Delete</Text>
</Pressable>
```

### Swipe Gestures
```typescript
// Swipe-to-delete on meal history items
import ReanimatedSwipeable from 'react-native-gesture-handler/ReanimatedSwipeable';

<ReanimatedSwipeable
  renderRightActions={() => (
    <Pressable onPress={deleteMeal} style={styles.deleteAction}>
      <Text style={styles.deleteText}>Delete</Text>
    </Pressable>
  )}
  overshootRight={false}
>
  <MealCard meal={meal} />
</ReanimatedSwipeable>
```

### Haptic Feedback
```typescript
import * as Haptics from 'expo-haptics';

// Light tap on button press
<Pressable onPress={() => {
  Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
  saveMeal();
}}>

// Success notification on meal saved
Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

// Warning on drift alert viewed
Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
```

---

## Form Input on Mobile

### Keyboard Management
```typescript
import { KeyboardAvoidingView, Platform } from 'react-native';

// Wrap forms to avoid keyboard covering inputs
<KeyboardAvoidingView
  behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
  keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0} // Account for tab bar height
>
  <ScrollView keyboardShouldPersistTaps="handled">
    {/* Form content */}
  </ScrollView>
</KeyboardAvoidingView>
```

### Input Types — Use the Right Keyboard
```typescript
// Calories — numeric keyboard, no decimals
<TextInput
  keyboardType="number-pad"    // Numeric only
  returnKeyType="done"
  placeholder="Calories"
  maxLength={5}
/>

// Protein — numeric with decimal
<TextInput
  keyboardType="decimal-pad"    // Numeric with decimal point
  placeholder="Protein (g)"
/>

// Food search — regular keyboard with search button
<TextInput
  keyboardType="default"
  returnKeyType="search"
  autoCorrect={false}
  autoCapitalize="none"
  placeholder="Search foods..."
/>

// Weight — numeric with decimal
<TextInput
  keyboardType="decimal-pad"
  placeholder="Weight (kg)"
/>
```

### Quick-Add Flow (Minimize Taps)

The #1 predictor of health app retention is logging friction. Every extra tap loses users.

```
Ideal meal logging flow:
1. Tap "+" on Log tab (1 tap)
2. See recent/frequent meals (0 taps if repeat meal)
3. Tap a recent meal → auto-fills name + calories (1 tap)
4. Adjust if needed, tap Save (1 tap)
Total: 2-3 taps for a repeat meal

Minimum viable quick-add:
1. Tap "+" → modal with meal type selector (Breakfast/Lunch/Dinner/Snack)
2. Calories field (numeric keyboard auto-focused)
3. Optional: protein, name
4. Save
Total: 4 taps + typing calories
```

---

## Loading and Empty States

### Skeleton Screens (Not Spinners)
```typescript
// Skeletons feel faster than spinners — the app looks "almost loaded"
import { MotiView } from 'moti';
import { Skeleton } from 'moti/skeleton';

function DashboardSkeleton() {
  return (
    <View style={styles.container}>
      <Skeleton colorMode="light" width="60%" height={24} />
      <View style={{ height: 12 }} />
      <Skeleton colorMode="light" width="100%" height={120} radius={12} />
      <View style={{ height: 12 }} />
      <Skeleton colorMode="light" width="100%" height={80} radius={12} />
    </View>
  );
}
```

### Empty States — First-Time User Experience
```typescript
// Don't show an empty list. Show guidance.
function EmptyMealHistory() {
  return (
    <View style={styles.emptyState}>
      <Ionicons name="restaurant-outline" size={64} color="#d1d5db" />
      <Text style={styles.emptyTitle}>No meals logged yet</Text>
      <Text style={styles.emptySubtitle}>
        Tap the + button to log your first meal, or import from Apple Health.
      </Text>
      <Pressable onPress={goToQuickAdd} style={styles.ctaButton}>
        <Text style={styles.ctaText}>Log Your First Meal</Text>
      </Pressable>
    </View>
  );
}
```

### Optimistic Updates (Offline-First)
```typescript
// Show the meal immediately, sync in background
async function saveMeal(meal: NewMeal) {
  // 1. Write to local SQLite immediately
  await db.insertMeal(meal);

  // 2. Add to sync queue
  await syncQueue.push({ type: 'CREATE', entity: 'MEAL', data: meal });

  // 3. UI reflects the new meal instantly (optimistic)
  // If sync fails, meal stays in queue for retry — user doesn't notice
}
```

---

## Offline UX

### Network Status Indicator
```typescript
import NetInfo from '@react-native-community/netinfo';

function useNetworkStatus() {
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state) => {
      setIsOnline(state.isConnected ?? true);
    });
    return unsubscribe;
  }, []);

  return isOnline;
}

// Subtle banner, not a modal
function OfflineBanner() {
  const isOnline = useNetworkStatus();
  if (isOnline) return null;

  return (
    <View style={styles.offlineBanner}>
      <Ionicons name="cloud-offline-outline" size={16} color="#fff" />
      <Text style={styles.offlineText}>Offline — changes will sync when connected</Text>
    </View>
  );
}
```

### Sync Status
```typescript
// Show last sync time on dashboard
function SyncStatusBadge() {
  const { lastSyncedAt, pendingChanges, isSyncing } = useSyncStore();

  if (isSyncing) return <Text style={styles.syncText}>Syncing...</Text>;
  if (pendingChanges > 0) {
    return <Text style={styles.syncText}>{pendingChanges} changes pending</Text>;
  }
  if (lastSyncedAt) {
    return <Text style={styles.syncText}>Synced {formatRelativeTime(lastSyncedAt)}</Text>;
  }
  return null;
}
```

### What Works Offline vs. What Doesn't
```typescript
// Make this clear in the UI
// ✅ Offline: Log meals, exercises, weight (queued for sync)
// ✅ Offline: View cached history, dashboard, drift charts
// ❌ Offline: Food search (requires API), import from HealthKit (might work if cached)
// ❌ Offline: Subscription management, account settings changes
```

---

## Health/Fitness App UX Patterns

### Dashboard Design
The dashboard answers one question: **"Am I still on track?"**

```
┌─────────────────────────────────┐
│ Good morning, Scott             │
│ ┌─────────────────────────────┐ │
│ │ This Week vs Baseline       │ │
│ │ Calories: ●●●●○  +8%  ↗   │ │  ← Drift indicator (within threshold)
│ │ Protein:  ●●●●●  -2%  →   │ │  ← On track
│ │ Exercise: ●●●○○  -15% ↘   │ │  ← Drifting (yellow/orange)
│ └─────────────────────────────┘ │
│                                 │
│ Today                           │
│ ┌──────┐ ┌──────┐ ┌──────┐    │
│ │B 450 │ │L --- │ │D --- │    │  ← Meal cards (logged vs empty)
│ └──────┘ └──────┘ └──────┘    │
│                                 │
│ Quick Actions                   │
│ [+ Log Meal]  [+ Log Exercise] │
└─────────────────────────────────┘
```

### Drift Visualization
```typescript
// Simple, intuitive drift indicators
// Arrow + percentage + color coding

// Green (on track): within ±5% of baseline
// Yellow (mild drift): ±5-15%
// Orange (notable drift): ±15-25%
// Red (significant drift): >±25%

// Use icons, not just colors (colorblind accessibility)
// ↗ trending up, → steady, ↘ trending down

function DriftIndicator({ percentage, direction }: DriftProps) {
  const color = getDriftColor(Math.abs(percentage));
  const icon = direction === 'up' ? 'trending-up' : direction === 'down' ? 'trending-down' : 'remove';

  return (
    <View style={[styles.badge, { backgroundColor: color + '20' }]}>
      <Ionicons name={icon} size={16} color={color} />
      <Text style={[styles.percentage, { color }]}>
        {percentage > 0 ? '+' : ''}{percentage}%
      </Text>
    </View>
  );
}
```

### Language and Tone
```typescript
// BAD: guilt-inducing
"You failed to meet your calorie target"
"Warning: You missed 3 exercises this week"
"Your weight increased"

// GOOD: observational and empowering
"Your lunch calories are trending 12% above baseline this week"
"Exercise frequency is down from 4x to 2x this week"
"Weight is up 0.8kg from last week — within normal fluctuation"

// BEST: actionable
"Lunch is trending higher — your last 3 lunches averaged 720 cal vs baseline 600 cal"
```

---

## Data Visualization on Mobile

### Chart Libraries for React Native
1. **Victory Native** — Most flexible, good TypeScript support, uses `react-native-svg`
2. **react-native-chart-kit** — Simple, good defaults, limited customization
3. **React Native Skia** (via `@shopify/react-native-skia`) — GPU-accelerated, maximum performance, steeper learning curve

**Recommendation for Iduna:** Victory Native for drift charts. Good balance of flexibility and simplicity.

### Small-Screen Chart Principles
- **Less data, bigger elements** — Max 7 data points on screen at once (one week)
- **Swipe to navigate time** — Swipe left/right for previous/next week
- **Tap for detail** — Tap a data point to see the exact value
- **Reference lines** — Always show the baseline as a dashed line
- **No legends** — Use inline labels or color-coded section headers instead

### Sparklines for Dashboard
```typescript
// Tiny inline chart showing trend at a glance
// 7 data points = this week's daily values
// No axes, no labels — just the shape
<View style={{ height: 30, width: 80 }}>
  <VictoryLine
    data={weeklyCalories}
    style={{ data: { stroke: getDriftColor(percentage), strokeWidth: 2 } }}
    padding={0}
    height={30}
    width={80}
  />
  {/* Baseline reference */}
  <VictoryLine
    data={[{ x: 0, y: baseline }, { x: 6, y: baseline }]}
    style={{ data: { stroke: '#d1d5db', strokeWidth: 1, strokeDasharray: '4,4' } }}
  />
</View>
```

---

## Onboarding Flow

### Progressive Disclosure — Don't Ask Everything Upfront

```
Step 1: Welcome + Value prop (why Iduna)
Step 2: Create account (Clerk sign-up)
Step 3: Set baseline (wizard)
  - "What's your typical daily calorie intake?" (slider or number input)
  - "How many meals per day?" (2-4 selector)
  - "Exercise frequency?" (days/week selector)
  - "Current weight?" (number input)
Step 4: "Want to import from Apple Health?" (OPTIONAL)
  - Pre-permission screen → system prompt
  - Skip button clearly visible
Step 5: "Get drift alerts?" (OPTIONAL)
  - Pre-permission screen → system prompt
  - Skip button clearly visible
Step 6: Dashboard (with sample data or first-time guidance)
```

**Key principles:**
- Optional features (Health, notifications) are SKIPPABLE
- Each step has a clear back button
- Progress indicator shows steps remaining
- Can complete onboarding in <60 seconds
- Never ask for permissions before explaining the value

---

## Accessibility

### VoiceOver (iOS) and TalkBack (Android)
```typescript
// All interactive elements need accessible labels
<Pressable
  onPress={logMeal}
  accessibilityLabel="Log a new meal"
  accessibilityRole="button"
>
  <Ionicons name="add-circle" size={48} color="#2563eb" />
</Pressable>

// Charts need text alternatives
<View
  accessibilityLabel={`Calorie drift chart: ${percentage}% ${direction} from baseline this week`}
  accessibilityRole="image"
>
  <DriftChart data={data} />
</View>

// Drift indicators need descriptive labels
<DriftIndicator
  percentage={12}
  direction="up"
  accessibilityLabel="Calories trending up 12 percent above baseline"
/>
```

### Dynamic Type / Font Scaling
```typescript
// React Native respects system font size by default
// But you must test with large fonts enabled

// Test on iOS: Settings > Accessibility > Display & Text Size > Larger Text
// Test on Android: Settings > Display > Font size

// Avoid fixed heights on text containers — use padding instead
// BAD
<View style={{ height: 48 }}><Text>Meal</Text></View>

// GOOD
<View style={{ paddingVertical: 12 }}><Text>Meal</Text></View>
```

### Color Accessibility
```typescript
// Drift indicators must work for colorblind users
// Don't rely on color alone — add icons and text

// BAD: Only red/green to indicate drift
<View style={{ backgroundColor: isGood ? 'green' : 'red' }} />

// GOOD: Color + icon + text
<View style={{ backgroundColor: isGood ? '#22c55e' : '#ef4444', flexDirection: 'row' }}>
  <Ionicons name={isGood ? 'checkmark-circle' : 'alert-circle'} />
  <Text>{isGood ? 'On track' : 'Drifting'}</Text>
</View>
```

---

## Performance Perception

### 60fps is Table Stakes
- Any dropped frames are visible as "jank"
- Heavy JS computation blocks the UI thread (pre-New Architecture)
- Animations should use `react-native-reanimated` (runs on UI thread, not JS thread)
- List scrolling must be 60fps — use FlashList, memo items, avoid inline object creation

### Fast Transitions
```typescript
// Use native stack transitions (Expo Router does this by default)
// Avoid custom JS-animated transitions unless necessary

// For modals, use native presentation:
<Stack.Screen
  name="quick-add"
  options={{ presentation: 'modal' }}  // Native iOS modal animation
/>
```

### Perceived Speed
- Show skeleton screens instead of spinners
- Optimistic updates for writes (show result before server confirms)
- Pre-fetch data on screen focus (not just on mount)
- Cache aggressively in expo-sqlite — network is the bottleneck, not storage

---

## Common UX Mistakes in Health Apps

1. **Too many required fields** — Requiring food name + calories + protein + fat + carbs + meal time kills logging compliance. Start with just calories + meal type. Add optional fields.

2. **Information overload on dashboard** — Showing 12 metrics at once is paralyzing. Show 3: calories, protein, exercise. Everything else is in History.

3. **Daily focus instead of trend focus** — "You ate 2,100 cal today" is less useful than "Your weekly average is trending up from baseline." Iduna's value prop IS trends, not daily counts.

4. **No positive reinforcement** — Only alerting on bad drift is demoralizing. Show "3 weeks on track" streaks, "Your exercise consistency improved" messages.

5. **Ignoring natural weight fluctuation** — ±2kg day-to-day is normal (water, sodium, timing). Don't alert on single-day weight changes. Alert on 2-week trends.

6. **Making the app feel like homework** — The moment logging feels like a chore, users stop. Minimize friction, celebrate consistency, never guilt.
