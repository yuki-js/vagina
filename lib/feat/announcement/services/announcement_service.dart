import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vagina/core/config/app_config.dart';
import 'package:vagina/feat/announcement/models/announcement_topic.dart';
import 'package:vagina/repositories/preferences_repository.dart';

typedef AnnouncementNowProvider = DateTime Function();

class AnnouncementService {
  final PreferencesRepository _preferencesRepository;
  final http.Client _httpClient;
  final Uri? _endpointUri;
  final AnnouncementNowProvider _nowProvider;
  final bool _ownsHttpClient;

  AnnouncementService({
    required PreferencesRepository preferencesRepository,
    http.Client? httpClient,
    Uri? endpointUri,
    AnnouncementNowProvider? nowProvider,
  })  : _preferencesRepository = preferencesRepository,
        _httpClient = httpClient ?? http.Client(),
        _endpointUri = endpointUri ?? AppConfig.announcementJsonUri,
        _nowProvider = nowProvider ?? DateTime.now,
        _ownsHttpClient = httpClient == null;

  Future<AnnouncementTopicList> fetchTopicList() async {
    final endpointUri = _endpointUri;
    if (endpointUri == null) {
      return const AnnouncementTopicList(topics: <AnnouncementTopic>[]);
    }

    final response = await _httpClient.get(endpointUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Failed to fetch announcements: HTTP ${response.statusCode}',
        endpointUri,
      );
    }

    final responseBody = utf8.decode(response.bodyBytes);
    return AnnouncementTopicList.fromJsonString(responseBody);
  }

  Future<List<AnnouncementTopic>> fetchActiveTopics({DateTime? now}) async {
    final topicList = await fetchTopicList();
    final dismissedTopicIds = await getDismissedTopicIds();
    return filterVisibleTopics(
      topicList.topics,
      now: now,
      dismissedTopicIds: dismissedTopicIds,
    );
  }

  List<AnnouncementTopic> filterVisibleTopics(
    Iterable<AnnouncementTopic> topics, {
    DateTime? now,
    Set<String>? dismissedTopicIds,
  }) {
    final effectiveNow = now ?? _nowProvider();
    final effectiveDismissedTopicIds = dismissedTopicIds ?? const <String>{};

    final visibleTopics = topics
        .where(
          (topic) =>
              topic.isActiveAt(effectiveNow) &&
              !effectiveDismissedTopicIds.contains(topic.id),
        )
        .toList();

    visibleTopics.sort(_compareTopics);
    return visibleTopics;
  }

  Future<Set<String>> getDismissedTopicIds() {
    return _preferencesRepository.getDismissedAnnouncementTopicIds();
  }

  Future<void> dismissTopic(String topicId) {
    return _preferencesRepository.addDismissedAnnouncementTopicId(topicId);
  }

  Future<void> restoreTopic(String topicId) {
    return _preferencesRepository.removeDismissedAnnouncementTopicId(topicId);
  }

  Future<void> clearDismissals() {
    return _preferencesRepository.clearDismissedAnnouncementTopicIds();
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  int _compareTopics(AnnouncementTopic left, AnnouncementTopic right) {
    final priorityComparison =
        right.priorityValue.compareTo(left.priorityValue);
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final startDateComparison = left.startDate.compareTo(right.startDate);
    if (startDateComparison != 0) {
      return startDateComparison;
    }

    return left.id.compareTo(right.id);
  }
}
