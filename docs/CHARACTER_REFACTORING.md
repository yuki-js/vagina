# Character/SpeedDial Non-Nullable Refactoring

This document describes the refactoring of the character/speed dial system to make the Default character a first-class entity.

## Problem Statement (Issue #89)

Previously, the system treated the "Default" character as a special case with nullable handling:
- Null character meant "use default"
- Special logic for null checks throughout the codebase
- Inconsistent abstractions

## Solution

Refactor to make characters **always non-nullable** with a mandatory Default character.

## Changes Made

### 1. SpeedDial Model

Location: `lib/models/speed_dial.dart`

The Default character is now a concrete instance:

```dart
class SpeedDial {
  static const String defaultId = 'default';
  
  static SpeedDial get defaultSpeedDial => SpeedDial(
    id: defaultId,
    name: 'Default',
    systemPrompt: 'You are a helpful AI assistant.',
    voice: 'alloy',
  );
  
  bool get isDefault => id == defaultId;
}
```

### 2. Repository Guarantees

Location: `lib/repositories/json_speed_dial_repository.dart`

The repository ensures Default character always exists:

```dart
Future<List<SpeedDial>> getAll() async {
  // ... load from storage
  
  // Ensure default speed dial always exists
  final hasDefault = speedDials.any((s) => s.id == SpeedDial.defaultId);
  if (!hasDefault) {
    speedDials.insert(0, SpeedDial.defaultSpeedDial);
    // Save the updated list
  }
  
  return speedDials;
}
```

### 3. Protection Mechanisms

**Cannot Delete Default:**
```dart
Future<bool> delete(String id) async {
  if (id == SpeedDial.defaultId) {
    _logService.warn(_tag, 'Cannot delete default speed dial');
    return false;
  }
  // ... proceed with deletion
}
```

**Cannot Rename Default:**
```dart
Future<bool> update(SpeedDial speedDial) async {
  if (speedDial.id == SpeedDial.defaultId) {
    final existing = await getById(SpeedDial.defaultId);
    if (existing != null && speedDial.name != existing.name) {
      _logService.warn(_tag, 'Cannot rename default speed dial');
      return false;
    }
  }
  // ... proceed with update
}
```

### 4. UI Changes

#### Speed Dial Card (Home Screen)

Location: `lib/screens/home/speed_dial_tab.dart`

```dart
// Show headset icon for default, emoji for custom
if (isDefault)
  const Icon(Icons.headset_mic, size: 48, color: AppTheme.primaryColor)
else
  Text(speedDial.iconEmoji ?? '⭐', style: const TextStyle(fontSize: 48)),
```

Prevents long-press edit on Default:
```dart
onLongPress: isDefault ? null : () => _editSpeedDial(context, speedDial),
```

#### Call Screen Display

Location: `lib/components/call_main_content.dart`

Dynamic display based on character:

**Default Character:**
- Icon: Headset (🎧)
- Name: "VAGINA"
- Subtitle: "Voice AGI Notepad Agent"

**Custom Character:**
- Icon: Custom emoji (e.g., 🎭)
- Name: Character name
- Subtitle: None

Removed old character badge that displayed name separately.

#### Configuration Screen

Location: `lib/screens/speed_dial/speed_dial_config_screen.dart`

For Default character:
- Name field: **Disabled** (cannot rename)
- Emoji selector: **Hidden** (always shows headset)
- Delete button: **Hidden** (cannot delete)
- Other fields: Editable (voice, system prompt)

### 5. Session Tracking

Location: `lib/models/call_session.dart`

All sessions now have non-nullable speedDialId:

```dart
class CallSession {
  final String speedDialId; // Non-nullable
  
  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      // ... other fields
      speedDialId: json['speedDialId'] as String? ?? SpeedDial.defaultId,
    );
  }
}
```

This provides backward compatibility with old sessions that didn't have speedDialId.

## Benefits

1. **Simplified Logic**: No null checks for character
2. **Type Safety**: Non-nullable eliminates null reference errors
3. **Consistency**: All calls have a character, no special cases
4. **Better UX**: Clear visual distinction between default and custom
5. **Data Integrity**: Always at least one character available

## Migration

Old data is automatically migrated:
- Existing sessions without speedDialId → Default character
- Empty speed dial list → Default character auto-created
- No manual migration required

## Testing

Unit tests: `test/models/speed_dial_test.dart`

Tests cover:
- Default character creation
- isDefault flag accuracy
- Serialization/deserialization
- copyWith functionality

## Future Enhancements

Potential improvements:
1. Allow users to customize the Default character's emoji
2. Multiple default characters for different contexts
3. Import/export character presets
4. Character templates library
