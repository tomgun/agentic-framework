# Mobile (React Native / Expo) Quality Knowledge

Deep domain expertise for building production mobile apps with React Native and Expo.

## JS Thread vs UI Thread

React Native has two main threads:
- **JS Thread**: Runs your JavaScript/TypeScript code, React rendering, business logic
- **UI Thread** (Main Thread): Handles native UI rendering, touch events, animations

### Golden Rule
Keep the JS thread free. Any computation >16ms on the JS thread causes visible frame drops.

### Common JS Thread Blockers
- Large list rendering without virtualization (FlatList/FlashList)
- Complex state updates in response to scroll events
- JSON parsing of large API responses
- Image processing or heavy computation
- Synchronous storage reads

### Solutions
```tsx
// BAD: Blocks JS thread on every scroll
onScroll={(e) => {
  const offset = e.nativeEvent.contentOffset.y
  setHeaderOpacity(Math.min(offset / 200, 1))  // Runs on JS thread
}}

// GOOD: Use reanimated — runs on UI thread
const scrollHandler = useAnimatedScrollHandler({
  onScroll: (event) => {
    opacity.value = Math.min(event.contentOffset.y / 200, 1)  // UI thread
  },
})
```

## List Performance

### FlatList Best Practices
```tsx
<FlatList
  data={items}
  renderItem={({ item }) => <ItemRow item={item} />}
  keyExtractor={(item) => item.id}
  getItemLayout={(data, index) => ({  // Skip measurement
    length: ITEM_HEIGHT,
    offset: ITEM_HEIGHT * index,
    index,
  })}
  windowSize={5}           // Render 5 screens worth
  maxToRenderPerBatch={10} // Render 10 items per batch
  removeClippedSubviews    // Unmount off-screen items (Android)
/>
```

### When to Use FlashList
If FlatList stutters with >100 items, switch to `@shopify/flash-list`. It recycles cells like native UITableView/RecyclerView. Drop-in replacement with 5-10x better performance.

## Navigation Patterns

### Deep Linking
```tsx
// app.config.ts (Expo)
{
  "expo": {
    "scheme": "myapp",
    "plugins": [["expo-router", { "root": "./app" }]]
  }
}

// Always validate deep link params
function ProfileScreen({ userId }) {
  // userId comes from URL — treat as untrusted
  if (!isValidUUID(userId)) return <NotFound />
  // ...
}
```

### Navigation State Persistence
```tsx
// Save navigation state for app resume
const [isReady, setIsReady] = useState(false)
const [initialState, setInitialState] = useState()

useEffect(() => {
  AsyncStorage.getItem('NAVIGATION_STATE').then(state => {
    if (state) setInitialState(JSON.parse(state))
    setIsReady(true)
  })
}, [])

<NavigationContainer
  initialState={initialState}
  onStateChange={state =>
    AsyncStorage.setItem('NAVIGATION_STATE', JSON.stringify(state))
  }
/>
```

## Offline-First Patterns

Mobile apps must handle poor/no connectivity gracefully.

### Strategy
1. Cache API responses locally (MMKV or SQLite)
2. Show cached data immediately, refresh in background
3. Queue mutations when offline, sync when connected
4. Show clear offline indicators

### Implementation with React Query
```tsx
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,  // Consider fresh for 5 minutes
      gcTime: 24 * 60 * 60 * 1000,  // Keep in cache for 24 hours
      networkMode: 'offlineFirst',
    },
  },
})
```

## App Store Guidelines

### Common Rejection Reasons
1. **Missing purpose string**: iOS requires explanation for every permission (camera, location, etc.)
2. **Background activity**: Don't run unnecessary background tasks (drains battery)
3. **Private API usage**: Don't access undocumented APIs
4. **Minimum functionality**: App must provide value beyond a website wrapper
5. **In-app purchases**: Digital goods must use Apple/Google IAP (30% cut)

### Pre-Submission Checklist
- [ ] All permission strings explain WHY (not just WHAT)
- [ ] App icon meets size requirements (1024x1024 for iOS)
- [ ] Screenshots for all required device sizes
- [ ] Privacy policy URL set in store listing
- [ ] App works without network (at minimum: shows cached state or clear error)
- [ ] Deep links tested on fresh install (no crash on cold start)

## Testing Mobile Apps

### Unit Tests (Jest)
```bash
npx jest --watchAll=false
```
Test: business logic, custom hooks, utility functions, navigation logic.

### Component Tests (RNTL)
```tsx
import { render, fireEvent } from '@testing-library/react-native'

test('login button submits form', () => {
  const onSubmit = jest.fn()
  const { getByText, getByPlaceholderText } = render(<LoginForm onSubmit={onSubmit} />)

  fireEvent.changeText(getByPlaceholderText('Email'), 'test@example.com')
  fireEvent.changeText(getByPlaceholderText('Password'), 'secret')
  fireEvent.press(getByText('Login'))

  expect(onSubmit).toHaveBeenCalledWith({
    email: 'test@example.com',
    password: 'secret',
  })
})
```

### E2E Tests (Detox)
```bash
npx detox build --configuration ios.sim.release
npx detox test --configuration ios.sim.release
```

### Manual Testing Checklist
- [ ] Test on both iOS and Android physical devices
- [ ] Test with slow network (Network Link Conditioner)
- [ ] Test with no network (airplane mode)
- [ ] Test after force-quit and relaunch
- [ ] Test deep links from external apps/browsers
- [ ] Test push notification tap when app is: foreground, background, killed
- [ ] Test with Dynamic Type (accessibility font sizes)
- [ ] Test with VoiceOver (iOS) / TalkBack (Android)
