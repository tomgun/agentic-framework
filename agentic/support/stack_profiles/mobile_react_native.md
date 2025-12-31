# Stack profile: React Native mobile app

Quick guidance for initializing a React Native mobile project with this framework.

## Tech choices

### Language & runtime
- React Native 0.72+ recommended
- Language: TypeScript
- Package management: `npm` or `yarn`
- Node: 18+ LTS

### Platform support
- iOS: Xcode 14+, iOS 13+ target
- Android: Android Studio, API level 21+ (Android 5.0+)

### Testing
- Unit tests: `jest` + `@testing-library/react-native`
- Component tests: `react-native-testing-library`
- E2E tests: `detox` or `maestro`
- Test command: `npm test`

### Common dependencies
- Navigation: `@react-navigation/native`
- State: `zustand`, `redux`, or React Context
- API: `axios` or `fetch`
- Storage: `@react-native-async-storage/async-storage`
- UI: `react-native-paper` or custom components

### Project structure (typical)
```
/src
  /screens      # Screen components
  /components   # Reusable components
  /navigation   # Navigation setup
  /services     # API clients, business logic
  /store        # State management
  /utils        # Utilities
/ios            # iOS native code
/android        # Android native code
/__tests__      # Tests
```

## STACK.md template sections

```markdown
## Setup
- Node: 18+ LTS
- Install: `npm install`
- iOS setup: `cd ios && pod install`
- Android setup: Ensure Android SDK installed

## Run
- Metro bundler: `npm start`
- iOS: `npm run ios` or open ios/*.xcworkspace in Xcode
- Android: `npm run android` or open android/ in Android Studio

## Test
- Unit: `npm test`
- E2E iOS: `detox test --configuration ios`
- E2E Android: `detox test --configuration android`

## Build
- iOS release: Xcode → Product → Archive
- Android release: `cd android && ./gradlew assembleRelease`

## Key constraints
- iOS 13+ target
- Android API 21+ (Android 5.0+)
- React Native 0.72+
```

## Test strategy guidance

### Unit tests
```typescript
import {render, fireEvent} from '@testing-library/react-native';
import {TodoItem} from '../components/TodoItem';

test('toggles todo on press', () => {
  const onToggle = jest.fn();
  const {getByText} = render(
    <TodoItem title="Test" onToggle={onToggle} />
  );
  
  fireEvent.press(getByText('Test'));
  expect(onToggle).toHaveBeenCalled();
});
```

### Integration tests
- Test navigation flows
- Test API integration with mock servers
- Test async storage operations

### E2E tests (Detox)
```javascript
describe('Todo app', () => {
  beforeAll(async () => {
    await device.launchApp();
  });

  it('should add new todo', async () => {
    await element(by.id('add-todo-input')).typeText('New task');
    await element(by.id('add-button')).tap();
    await expect(element(by.text('New task'))).toBeVisible();
  });
});
```

## NFR considerations

For `spec/NFR.md`:
- **Performance**: 60fps scrolling, JS thread < 16ms per frame
- **Offline**: App usable without network (cache data locally)
- **Battery**: Minimize background activity, location polling
- **Bundle size**: Monitor JS bundle size (affects startup time)
- **Permissions**: Document required permissions (camera, location, etc.)

Mobile-specific NFRs:
- `NFR-0001`: App launches in <3 seconds on mid-range devices
- `NFR-0002`: Handles poor network gracefully (timeouts, retries, offline mode)
- `NFR-0003`: Works on screen sizes 4" to 6.5"
- `NFR-0004`: Supports iOS dark mode, Android Material You themes

## Feature tracking patterns

Mobile features often include platform-specific acceptance:
- F-0010: Push notifications
  - Acceptance includes: iOS permissions, Android Firebase setup, notification display, deep linking

## Common gotchas

- **Platform differences**: iOS vs Android behavior diverges (navigation, permissions)
- **Native modules**: Some require linking, pod install, or gradle sync
- **Simulator vs device**: Test on real devices for accurate performance
- **Version compatibility**: React Native upgrades can break native code
- **Debugging**: Use Flipper for debugging, Metro bundler logs

## Acceptance criteria patterns

Mobile-specific criteria:
- "Works on iOS 13+ and Android 5.0+"
- "Handles poor network (retry, offline mode)"
- "Requests permissions appropriately (with rationale)"
- "Adapts to screen sizes 4" to 6.5""
- "60fps scrolling for lists with 100+ items"
- "App bundle <30MB"

## Code annotations

```typescript
// @feature F-0020
// @nfr NFR-0003 (60fps scrolling)
export const TodoList: React.FC<Props> = ({todos}) => {
  return (
    <FlatList
      data={todos}
      renderItem={renderTodo}
      initialNumToRender={20}
      maxToRenderPerBatch={10}
      windowSize={10}
    />
  );
};
```

## References

- React Native docs: https://reactnative.dev/docs/getting-started
- Testing: https://callstack.github.io/react-native-testing-library/
- Detox E2E: https://wix.github.io/Detox/
- Performance: https://reactnative.dev/docs/performance

