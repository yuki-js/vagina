# flutter_sound Race Condition Bug Analysis

## Overview

This document provides a comprehensive analysis of a race condition bug in the `flutter_sound` library (`flutter_sound_core`) that causes a fatal SIGSEGV crash on Android when using the streaming playback feature (`feedFromStream()`).

## Summary

| Aspect | Details |
|--------|---------|
| **Repository** | [Canardoux/flutter_sound_core](https://github.com/Canardoux/flutter_sound_core) |
| **Affected File** | `android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java` |
| **Bug Type** | Race condition leading to null pointer dereference |
| **Impact** | Fatal crash (SIGSEGV signal 11) |
| **Severity** | High (application crash) |
| **Security Vulnerability** | No (see security analysis below) |
| **Existing Issue** | [#1123](https://github.com/Canardoux/flutter_sound/issues/1123) (inadequate report, dismissed by maintainer) |

## Problem Description

### Symptoms

When calling `feedFromStream()` or `feedUint8FromStream()` rapidly (e.g., real-time audio streaming from an API), the Android app crashes with:

```
Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0
Cause: null pointer dereference
#00 pc ...  /system/lib64/libaudioclient.so (android::AudioTrack::releaseBuffer)
#01 pc ...  /system/lib64/libaudioclient.so (android::AudioTrack::write)
...
#10 pc ...  xyz.canardoux.TauEngine.FlautoPlayerEngine$FeedThread.run
```

### Root Cause

The `feed()` method in `FlautoPlayerEngine.java` spawns a new thread for each call without any synchronization:

```java
// FlautoPlayerEngine.java (lines 304-308)
int feed(byte[] data) throws Exception {
    FeedThread t = new FeedThread(data);
    t.start();
    return 0;
}
```

The `FeedThread.run()` method directly accesses `audioTrack` without synchronization:

```java
// FlautoPlayerEngine.java (lines 113-128)
class FeedThread extends Thread {
    byte[] mData = null;

    FeedThread(byte[] data) {
        mData = data;
    }

    public void run() {
        int ln = 0;
        if (mCodec == Flauto.t_CODEC.pcmFloat32) {
            // ... Float32 handling
        } else {
            ln = audioTrack.write(mData, 0, mData.length, AudioTrack.WRITE_BLOCKING);
        }
        mSession.needSomeFood(1);
    }
}
```

### Race Condition Scenarios

**Scenario 1: Concurrent Write Calls**
```
Thread 1: audioTrack.write() [in progress]
Thread 2: audioTrack.write() [starts while Thread 1 still writing]
Result: Undefined behavior, potential buffer corruption
```

**Scenario 2: Stop While Writing**
```
Thread 1: audioTrack.write() [in progress]
Main Thread: _stop() -> audioTrack.release() -> audioTrack = null
Thread 1: Continues write -> null pointer dereference -> SIGSEGV
```

### Permalink to Problematic Code

- **feed() method**: https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java#L304-L308
- **FeedThread class**: https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java#L113-L128
- **_stop() method**: https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java#L254-L260

## Is This Intentional (Like Rust's `unsafe`)?

**No, this is NOT an intentional design choice.**

In Rust, race conditions for performance are:
1. Explicitly documented with safety contracts
2. Opt-in via `unsafe` keyword
3. Caller knows they must provide external synchronization

In flutter_sound:
1. **No documentation** warns about thread safety requirements
2. **No "unsafe" annotation** or equivalent exists
3. The maintainer's response to issue #1123 was: "you have somewhere a reference to a not initialized variable" - indicating **unawareness** of the race condition
4. The API is designed to look safe (simple `feedFromStream()` call)

## Security Analysis

### Is This a Security Vulnerability?

**No**, this is a reliability/availability issue, not a security vulnerability.

### Analysis

| Security Aspect | Assessment |
|-----------------|------------|
| **Arbitrary Code Execution** | No - SIGSEGV causes immediate termination, no code injection possible |
| **Information Disclosure** | No - Crash doesn't leak memory contents |
| **Denial of Service** | Partial - Crash only affects the current app instance, not system-wide |
| **Privilege Escalation** | No - AudioTrack runs in app's user context |
| **Memory Corruption Exploitation** | No - Android's ASLR + stack canaries make exploitation impractical |

### Could This Enable Other Vulnerabilities?

Theoretically, if an attacker could:
1. Control the timing of `feed()` calls precisely
2. Cause a specific memory corruption pattern
3. Bypass Android's memory protections

They might achieve use-after-free exploitation. However:
- **Attack vector is impractical**: Attacker would need to control audio data being fed to the player
- **Timing is unpredictable**: Thread scheduling is non-deterministic
- **Android mitigations are strong**: ASLR, stack canaries, SELinux

**Conclusion**: This is NOT a security vulnerability requiring CVE assignment.

## Reproduction

### Prerequisites
- Android device or emulator (API 29+)
- flutter_sound package installed
- App that calls `feedFromStream()` rapidly

### Steps to Reproduce
1. Start audio player with `startPlayerFromStream(codec: Codec.pcm16, sampleRate: 24000)`
2. Call `feedFromStream()` repeatedly in rapid succession (every 50-100ms)
3. While streaming, call `stopPlayer()` or dispose the player
4. **Result**: SIGSEGV crash

### Reproduction Code

See the reproduction screen in our app: `lib/screens/flutter_sound_bug_repro_screen.dart`

```dart
// Minimal reproduction
final player = FlutterSoundPlayer();
await player.openPlayer();
await player.startPlayerFromStream(
  codec: Codec.pcm16,
  sampleRate: 24000,
  numChannels: 1,
);

// Rapid feed calls - this will eventually crash
for (int i = 0; i < 100; i++) {
  await player.feedFromStream(generateRandomPCM16(2400)); // 100ms of audio
  await Future.delayed(Duration(milliseconds: 50));
}

// Stop while threads are still running
await player.stopPlayer(); // CRASH!
```

## Suggested Fix

### Option 1: Synchronized Feed Method

```java
private final Object audioLock = new Object();
private volatile boolean isPlaying = false;

int feed(byte[] data) throws Exception {
    if (!isPlaying) return 0;
    
    synchronized(audioLock) {
        if (audioTrack != null && 
            audioTrack.getPlayState() == AudioTrack.PLAYSTATE_PLAYING) {
            audioTrack.write(data, 0, data.length, AudioTrack.WRITE_BLOCKING);
        }
    }
    mSession.needSomeFood(1);
    return 0;
}

void _stop() {
    isPlaying = false;
    synchronized(audioLock) {
        if (audioTrack != null) {
            audioTrack.stop();
            audioTrack.release();
            audioTrack = null;
        }
    }
}
```

### Option 2: Single Background Thread with Queue

```java
private final BlockingQueue<byte[]> audioQueue = new LinkedBlockingQueue<>();
private Thread feedThread;

int feed(byte[] data) throws Exception {
    audioQueue.offer(data);
    return 0;
}

void startFeedThread() {
    feedThread = new Thread(() -> {
        while (isPlaying) {
            try {
                byte[] data = audioQueue.poll(100, TimeUnit.MILLISECONDS);
                if (data != null && audioTrack != null) {
                    audioTrack.write(data, 0, data.length, AudioTrack.WRITE_BLOCKING);
                    mSession.needSomeFood(1);
                }
            } catch (InterruptedException e) {
                break;
            }
        }
    });
    feedThread.start();
}
```

## Our Workaround

In our app (`AudioPlayerService`), we implemented a Dart-side queue to serialize feed calls:

```dart
final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
bool _isProcessingQueue = false;

Future<void> addAudioData(Uint8List pcmData) async {
    _audioQueue.add(pcmData);
    await _processAudioQueue();
}

Future<void> _processAudioQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    
    try {
        while (_audioQueue.isNotEmpty && _isPlaying) {
            final chunk = _audioQueue.removeFirst();
            await _player!.feedUint8FromStream(chunk);
            await Future.delayed(Duration(milliseconds: 1));
        }
    } finally {
        _isProcessingQueue = false;
    }
}
```

This prevents concurrent `feedFromStream()` calls from reaching the native layer.

## Issue Submission Template

### Title
Race condition in feedFromStream() causes SIGSEGV on Android (null pointer dereference in AudioTrack)

### Description

Calling `feedFromStream()` or `feedUint8FromStream()` multiple times concurrently causes a fatal SIGSEGV crash on Android.

### Root Cause

In `FlautoPlayerEngine.java`, the `feed()` method spawns a new thread for each call:
https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java#L304-L308

The `FeedThread` accesses `audioTrack` without synchronization:
https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java#L113-L128

When `_stop()` is called while threads are still writing, the `audioTrack` is released and set to null, causing a null pointer dereference.

### Stack Trace
```
signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0x0
Cause: null pointer dereference
#00 pc ... libaudioclient.so (android::AudioTrack::releaseBuffer)
#01 pc ... libaudioclient.so (android::AudioTrack::write)
...
#10 pc ... FlautoPlayerEngine$FeedThread.run
```

### Environment
- flutter_sound: 9.x
- Android API: 29+
- Flutter: 3.x

### Suggested Fix
Add synchronization to `FlautoPlayerEngine`:
1. Use `synchronized` block around `audioTrack` access
2. Or use a single background thread with a queue

See attached patch file.

## References

- [flutter_sound issue #1123](https://github.com/Canardoux/flutter_sound/issues/1123) - Original inadequate bug report
- [FlautoPlayerEngine.java source](https://github.com/Canardoux/flutter_sound_core/blob/ab5d0be291d81b1964ea1a6f2733c027d342c1cc/android/src/main/java/xyz/canardoux/TauEngine/FlautoPlayerEngine.java)
- [Android AudioTrack documentation](https://developer.android.com/reference/android/media/AudioTrack)

---

*Document created: 2025-11-27*
*Last updated: 2025-11-27*
