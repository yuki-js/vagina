# Audio Feedback Implementation

This document describes the audio feedback system for call lifecycle events.

## Overview

The application provides audio feedback during call start and end to improve user experience and provide clear indication of call state changes.

## Components

### CallAudioFeedbackService

Location: `lib/services/call_audio_feedback_service.dart`

A dedicated service for managing call audio feedback using the `just_audio` package.

#### Methods

- **playDialTone()**: Plays a looping dial tone when connecting
- **stopDialTone()**: Stops the dial tone when connected
- **playCallEndTone()**: Plays a single "piron" sound when call ends
- **dispose()**: Cleans up audio resources

### Audio Assets

Location: `assets/audio/`

Two audio files generated programmatically:

#### dial_tone.wav
- **Duration**: 0.8 seconds
- **Frequencies**: Dual-tone (350Hz + 440Hz)
- **Behavior**: Loops continuously during connection
- **Volume**: 30% to avoid being intrusive
- **Purpose**: Indicates the app is connecting to the AI service

#### call_end.wav
- **Duration**: ~0.39 seconds
- **Tones**: Three ascending notes (C5→E5→G5)
  - C5 (523Hz) - 120ms
  - E5 (659Hz) - 120ms
  - G5 (784Hz) - 150ms
- **Behavior**: Plays once when call ends
- **Volume**: 50%
- **Purpose**: Pleasant "piron" sound to confirm call termination

## Integration

### In CallService

The CallAudioFeedbackService is integrated into CallService:

```dart
final CallAudioFeedbackService _audioFeedback;

CallService({
  // ... other parameters
  CallAudioFeedbackService? audioFeedback,
}) : _audioFeedback = audioFeedback ?? CallAudioFeedbackService(logService: logService);
```

### Call Flow

1. **Starting Call**:
   - User presses call button
   - Dial tone starts playing (looping)
   - App connects to Azure OpenAI Realtime API
   - Once connected, dial tone stops
   
2. **During Call**:
   - No audio feedback (only user's voice and AI responses)

3. **Ending Call**:
   - User presses end call button
   - End tone plays once ("piron")
   - Call terminates and returns to home screen

### Error Handling

All audio operations are wrapped in try-catch blocks to ensure:
- Audio failures don't crash the app
- Errors are logged for debugging
- Call functionality continues even if audio fails

## Platform Support

The audio feedback works on:
- ✅ Web (via HTML5 Audio)
- ✅ Android
- ✅ iOS
- ✅ Windows
- ✅ macOS
- ✅ Linux

## User Experience Considerations

### Volume Levels
- Dial tone: 30% to avoid startling users
- End tone: 50% to be clearly audible but not jarring

### Timing
- Dial tone starts immediately when connecting
- Dial tone stops as soon as connection is established
- End tone plays after call is terminated (not during)

### Accessibility
- Visual indicators also present (connecting spinner, duration timer)
- Audio is supplementary, not required for functionality
- Future: Add setting to disable audio feedback

## Testing

Unit tests: `test/services/call_audio_feedback_service_test.dart`

Note: Actual audio playback cannot be tested in unit tests as it requires platform channels. These tests verify:
- Service initialization
- Disposal without errors
- API surface contract

## Future Enhancements

Potential improvements:
1. User setting to enable/disable audio feedback
2. Custom sound selection
3. Volume control
4. Different sounds for different call states (e.g., incoming call, connection failed)
5. Haptic feedback integration
