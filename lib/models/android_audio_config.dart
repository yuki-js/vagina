import 'package:record/record.dart';

/// Configuration for Android-specific audio recording settings
class AndroidAudioConfig {
  /// The audio source to use for recording
  final AndroidAudioSource audioSource;

  /// The audio manager mode to use
  final AudioManagerMode audioManagerMode;

  /// Available audio sources with their display names
  static const Map<AndroidAudioSource, String> audioSourceDisplayNames = {
    AndroidAudioSource.defaultSource: 'Default',
    AndroidAudioSource.mic: 'Mic',
    AndroidAudioSource.voiceUplink: 'Voice Uplink',
    AndroidAudioSource.voiceDownlink: 'Voice Downlink',
    AndroidAudioSource.voiceCall: 'Voice Call',
    AndroidAudioSource.camcorder: 'Camcorder',
    AndroidAudioSource.voiceRecognition: 'Voice Recognition',
    AndroidAudioSource.voiceCommunication: 'Voice Communication',
    AndroidAudioSource.remoteSubMix: 'Remote SubMix',
    AndroidAudioSource.unprocessed: 'Unprocessed',
    AndroidAudioSource.voicePerformance: 'Voice Performance',
  };

  /// Available audio manager modes with their display names
  static const Map<AudioManagerMode, String> audioModeDisplayNames = {
    AudioManagerMode.modeNormal: 'Normal',
    AudioManagerMode.modeRingtone: 'Ringtone',
    AudioManagerMode.modeInCall: 'In Call',
    AudioManagerMode.modeInCommunication: 'In Communication',
    AudioManagerMode.modeCallScreening: 'Call Screening',
    AudioManagerMode.modeCallRedirect: 'Call Redirect',
    AudioManagerMode.modeCommunicationRedirect: 'Communication Redirect',
  };

  const AndroidAudioConfig({
    this.audioSource = AndroidAudioSource.voiceCommunication,
    this.audioManagerMode = AudioManagerMode.modeInCommunication,
  });

  AndroidAudioConfig copyWith({
    AndroidAudioSource? audioSource,
    AudioManagerMode? audioManagerMode,
  }) {
    return AndroidAudioConfig(
      audioSource: audioSource ?? this.audioSource,
      audioManagerMode: audioManagerMode ?? this.audioManagerMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioSource': audioSource.name,
      'audioManagerMode': audioManagerMode.name,
    };
  }

  factory AndroidAudioConfig.fromJson(Map<String, dynamic> json) {
    return AndroidAudioConfig(
      audioSource: AndroidAudioSource.values.firstWhere(
        (e) => e.name == json['audioSource'],
        orElse: () => AndroidAudioSource.voiceCommunication,
      ),
      audioManagerMode: AudioManagerMode.values.firstWhere(
        (e) => e.name == json['audioManagerMode'],
        orElse: () => AudioManagerMode.modeInCommunication,
      ),
    );
  }
}
