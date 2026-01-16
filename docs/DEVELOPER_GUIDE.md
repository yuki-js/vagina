# Developer Migration Guide

## Overview

This guide helps developers understand and work with the new feature-based architecture implemented in the refactoring of issues #88 and #94.

## What Changed?

### Before
- All providers in a single 392-line file
- Components scattered across the codebase
- No clear feature boundaries

### After
- Feature-based organization with components + providers co-located
- Clear separation between infrastructure and features
- Improved discoverability and maintainability

## Working with Features

### Feature Directory Structure

Each feature now follows this pattern:
```
lib/features/FEATURE_NAME/
├── components/     # UI components for this feature
├── providers/      # State management for this feature
└── (future: services/, models/, etc.)
```

### Current Features

#### 1. Call Feature (`lib/features/call/`)
**Purpose**: Voice call functionality

**Components**:
- `chat_header.dart` - Chat page header
- `scroll_to_bottom_button.dart` - Scroll control
- `notepad_header.dart` - Notepad header
- `notepad_tab_bar.dart` - Tab navigation
- `notepad_tab_item.dart` - Individual tab

**Providers** (`call_providers.dart`):
- Audio management (`audioRecorderServiceProvider`, `audioPlayerServiceProvider`)
- Call state (`callServiceProvider`, `callStateProvider`)
- WebSocket communication (`webSocketServiceProvider`, `realtimeApiClientProvider`)
- Assistant configuration (`assistantConfigProvider`)
- UI state (`isMutedProvider`, `speakerMutedProvider`)

**When to use**: Working on call screen, audio, or chat functionality

#### 2. Notepad Feature (`lib/features/notepad/`)
**Purpose**: Document/notepad management

**Providers** (`notepad_providers.dart`):
- `notepadServiceProvider` - Core notepad service
- `notepadTabsProvider` - Tab list
- `selectedNotepadTabIdProvider` - Current tab

**When to use**: Working on document editing or notepad features

#### 3. Session Feature (`lib/features/session/`)
**Purpose**: Call session history and speed dials

**Components**:
- `session_info_view.dart` - Session detail display

**Providers** (`session_providers.dart`):
- `speedDialsProvider` - Speed dial list
- `callSessionsProvider` - Session history
- Refresh providers for updating lists

**When to use**: Working on session history or speed dial features

#### 4. Settings Feature (`lib/features/settings/`)
**Purpose**: Application settings

**Components**:
- `setup_section.dart` - OOBE restart section

**Providers** (`settings_providers.dart`):
- `androidAudioConfigProvider` - Android audio settings
- `useCupertinoStyleProvider` - UI style preference

**When to use**: Working on settings screens or configuration

## Import Patterns

### Option 1: Backward Compatible (Recommended for existing code)
```dart
import '../../providers/providers.dart';
```
This works for all providers through re-exports.

### Option 2: Feature-Specific (Recommended for new code)
```dart
// Call feature
import '../../features/call/providers/call_providers.dart';
import '../../features/call/components/chat_header.dart';

// Notepad feature
import '../../features/notepad/providers/notepad_providers.dart';

// Settings feature
import '../../features/settings/providers/settings_providers.dart';
import '../../features/settings/components/setup_section.dart';

// Infrastructure
import '../../providers/core_providers.dart';
import '../../providers/repository_providers.dart';
```

### Option 3: Mixed (When using multiple features)
```dart
// Use general import for convenience
import '../../providers/providers.dart';

// Or import specific features
import '../../features/call/providers/call_providers.dart';
import '../../features/notepad/providers/notepad_providers.dart';
```

## Adding New Features

### 1. Create Feature Directory
```bash
mkdir -p lib/features/your_feature/components
mkdir -p lib/features/your_feature/providers
```

### 2. Add Providers
Create `lib/features/your_feature/providers/your_feature_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/core_providers.dart'; // If needed
// ... other imports

// Your providers here
final yourFeatureProvider = Provider<YourService>((ref) {
  return YourService();
});
```

### 3. Add Components
Create components in `lib/features/your_feature/components/`:
```dart
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
// ... other imports

class YourFeatureComponent extends StatelessWidget {
  // Your component implementation
}
```

### 4. Export in Main Providers File (Optional)
If you want backward compatibility, add to `lib/providers/providers.dart`:
```dart
export '../features/your_feature/providers/your_feature_providers.dart';
```

### 5. Add Screen
Screens still go in `lib/screens/your_feature/`:
```dart
import '../../features/your_feature/providers/your_feature_providers.dart';
import '../../features/your_feature/components/your_component.dart';
```

## Common Patterns

### Accessing Providers from Components
```dart
class MyComponent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read provider
    final service = ref.read(yourServiceProvider);
    
    // Watch provider
    final state = ref.watch(yourStateProvider);
    
    return YourWidget();
  }
}
```

### Creating Feature-Specific State
```dart
// In features/your_feature/providers/your_feature_providers.dart

// Simple state
final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  void increment() => state++;
}

// Async state
final dataProvider = FutureProvider<Data>((ref) async {
  return await fetchData();
});
```

## Guidelines

### DO ✅
- Put feature-specific components in `features/FEATURE/components/`
- Put feature-specific providers in `features/FEATURE/providers/`
- Keep truly shared components in `lib/components/`
- Keep infrastructure providers in `lib/providers/`
- Import from features for new code
- Follow the established pattern for new features

### DON'T ❌
- Don't mix features (call code in notepad feature)
- Don't put feature code in shared directories
- Don't create circular dependencies between features
- Don't put infrastructure code in features
- Don't break backward compatibility (keep re-exports)

## Troubleshooting

### Import not found
```
Error: Target of URI doesn't exist
```
**Solution**: Check if you're using the correct path:
- Features: `../../features/FEATURE/providers/...`
- Shared: `../../providers/...`
- Components: `../../features/FEATURE/components/...`

### Circular dependency
```
Error: Circular dependency detected
```
**Solution**: 
1. Check if feature A imports feature B and vice versa
2. Extract shared code to `lib/services/` or `lib/models/`
3. Use `providers.dart` re-exports instead of direct imports

### Provider not found
```
Error: Undefined name 'someProvider'
```
**Solution**:
1. Import the correct providers file
2. Check if provider is exported in `lib/providers/providers.dart`
3. Verify provider name matches

## Testing

### Unit Tests
Test providers independently:
```dart
test('provider returns expected value', () {
  final container = ProviderContainer();
  final value = container.read(yourProvider);
  expect(value, expectedValue);
});
```

### Widget Tests
Use `ProviderScope` for widgets:
```dart
testWidgets('widget test', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: YourWidget(),
    ),
  );
  // Your assertions
});
```

## Examples

### Example 1: Adding a new "Profile" feature

```bash
# Create directories
mkdir -p lib/features/profile/components
mkdir -p lib/features/profile/providers
```

```dart
// lib/features/profile/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileProvider = FutureProvider<Profile>((ref) async {
  return await fetchProfile();
});
```

```dart
// lib/features/profile/components/profile_card.dart
import 'package:flutter/material.dart';

class ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(/* ... */);
  }
}
```

```dart
// lib/screens/profile/profile_screen.dart
import '../../features/profile/providers/profile_providers.dart';
import '../../features/profile/components/profile_card.dart';

class ProfileScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(/* ... */);
  }
}
```

## Questions?

If you have questions about the new architecture:
1. Read `docs/REFACTORING.md` for detailed overview
2. Look at existing features as examples
3. Follow the patterns established in call/notepad/session/settings
4. Ask the team for clarification

## Resources

- [Riverpod Documentation](https://riverpod.dev)
- [Flutter Architecture Patterns](https://flutter.dev/docs/development/data-and-backend/state-mgmt/options)
- Project `docs/REFACTORING.md` - Detailed refactoring overview
