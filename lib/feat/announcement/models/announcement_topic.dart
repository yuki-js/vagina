import 'dart:convert';

enum AnnouncementTopicType {
  banner,
  modal,
  dialog,
  marquee,
}

enum AnnouncementActionType {
  openLink,
  dismissTopic,
}

class AnnouncementTopicList {
  final List<AnnouncementTopic> topics;

  const AnnouncementTopicList({required this.topics});

  factory AnnouncementTopicList.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['topics'];
    if (rawTopics is! List) {
      throw const FormatException(
        'Announcement topic list must contain a topics array.',
      );
    }

    return AnnouncementTopicList(
      topics: rawTopics.map((rawTopic) {
        if (rawTopic is! Map) {
          throw const FormatException(
            'Announcement topic entries must be JSON objects.',
          );
        }

        return AnnouncementTopic.fromJson(
          Map<String, dynamic>.from(rawTopic),
        );
      }).toList(),
    );
  }

  factory AnnouncementTopicList.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException(
        'Announcement JSON root must be an object.',
      );
    }

    return AnnouncementTopicList.fromJson(Map<String, dynamic>.from(decoded));
  }

  Map<String, dynamic> toJson() {
    return {
      'topics': topics.map((topic) => topic.toJson()).toList(),
    };
  }
}

abstract class AnnouncementAction {
  final AnnouncementActionType actionType;

  const AnnouncementAction(this.actionType);

  factory AnnouncementAction.fromJson(Map<String, dynamic> json) {
    switch (_readActionType(json)) {
      case AnnouncementActionType.openLink:
        return OpenLinkAnnouncementAction.fromJson(json);
      case AnnouncementActionType.dismissTopic:
        return DismissTopicAnnouncementAction.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

class OpenLinkAnnouncementAction extends AnnouncementAction {
  final String linkUrl;

  const OpenLinkAnnouncementAction({required this.linkUrl})
      : super(AnnouncementActionType.openLink);

  factory OpenLinkAnnouncementAction.fromJson(Map<String, dynamic> json) {
    return OpenLinkAnnouncementAction(
      linkUrl: _readRequiredString(json, 'linkUrl'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'actionType': _actionTypeToJsonValue(actionType),
      'linkUrl': linkUrl,
    };
  }
}

class DismissTopicAnnouncementAction extends AnnouncementAction {
  final bool showAgain;

  const DismissTopicAnnouncementAction({this.showAgain = false})
      : super(AnnouncementActionType.dismissTopic);

  factory DismissTopicAnnouncementAction.fromJson(Map<String, dynamic> json) {
    final actionType = _readActionType(json);
    if (actionType != AnnouncementActionType.dismissTopic) {
      throw FormatException(
        'Expected dismissTopic action but found ${_actionTypeToJsonValue(actionType)}.',
      );
    }

    return DismissTopicAnnouncementAction(
      showAgain: _readOptionalBool(json, 'showAgain') ?? false,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'actionType': _actionTypeToJsonValue(actionType),
      if (showAgain) 'showAgain': showAgain,
    };
  }
}

class AnnouncementButton {
  final String label;
  final bool isPrimary;
  final bool isNegative;
  final AnnouncementAction action;

  const AnnouncementButton({
    required this.label,
    required this.isPrimary,
    required this.isNegative,
    required this.action,
  });

  factory AnnouncementButton.fromJson(Map<String, dynamic> json) {
    return AnnouncementButton(
      label: _readRequiredString(json, 'label'),
      isPrimary: _readRequiredBool(json, 'isPrimary'),
      isNegative: _readRequiredBool(json, 'isNegative'),
      action: AnnouncementAction.fromJson(_readRequiredMap(json, 'action')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'isPrimary': isPrimary,
      'isNegative': isNegative,
      'action': action.toJson(),
    };
  }
}

class AnnouncementVisualContent {
  final String imageUrl;
  final String altText;

  const AnnouncementVisualContent({
    required this.imageUrl,
    required this.altText,
  });

  factory AnnouncementVisualContent.fromJson(Map<String, dynamic> json) {
    return AnnouncementVisualContent(
      imageUrl: _readRequiredString(json, 'imageUrl'),
      altText: _readRequiredString(json, 'altText'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'altText': altText,
    };
  }
}

abstract class AnnouncementTopic {
  final String id;
  final AnnouncementTopicType type;
  final DateTime startDate;
  final DateTime endDate;
  final int? priority;

  const AnnouncementTopic({
    required this.id,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.priority,
  });

  int get priorityValue => priority ?? 0;

  bool isActiveAt(DateTime dateTime) {
    return !dateTime.isBefore(startDate) && !dateTime.isAfter(endDate);
  }

  factory AnnouncementTopic.fromJson(Map<String, dynamic> json) {
    switch (_readTopicType(json)) {
      case AnnouncementTopicType.banner:
        return BannerAnnouncementTopic.fromJson(json);
      case AnnouncementTopicType.modal:
        return ModalAnnouncementTopic.fromJson(json);
      case AnnouncementTopicType.dialog:
        return DialogAnnouncementTopic.fromJson(json);
      case AnnouncementTopicType.marquee:
        return MarqueeAnnouncementTopic.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

class BannerAnnouncementTopic extends AnnouncementTopic {
  final AnnouncementVisualContent image;
  final AnnouncementAction? action;
  final AnnouncementAction? dismissingAction;

  BannerAnnouncementTopic({
    required super.id,
    required super.startDate,
    required super.endDate,
    super.priority,
    required this.image,
    this.action,
    this.dismissingAction,
  }) : super(type: AnnouncementTopicType.banner);

  factory BannerAnnouncementTopic.fromJson(Map<String, dynamic> json) {
    final base = _readTopicBaseFields(json);
    return BannerAnnouncementTopic(
      id: base.id,
      startDate: base.startDate,
      endDate: base.endDate,
      priority: base.priority,
      image:
          AnnouncementVisualContent.fromJson(_readRequiredMap(json, 'image')),
      action: _readOptionalAction(json, 'action'),
      dismissingAction: _readOptionalAction(json, 'dismissingAction'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ..._baseTopicJson(this),
      'image': image.toJson(),
      if (action != null) 'action': action!.toJson(),
      if (dismissingAction != null)
        'dismissingAction': dismissingAction!.toJson(),
    };
  }
}

class ModalAnnouncementTopic extends AnnouncementTopic {
  final AnnouncementVisualContent image;
  final AnnouncementAction? action;
  final AnnouncementAction? dismissingAction;

  ModalAnnouncementTopic({
    required super.id,
    required super.startDate,
    required super.endDate,
    super.priority,
    required this.image,
    this.action,
    this.dismissingAction,
  }) : super(type: AnnouncementTopicType.modal);

  factory ModalAnnouncementTopic.fromJson(Map<String, dynamic> json) {
    final base = _readTopicBaseFields(json);
    return ModalAnnouncementTopic(
      id: base.id,
      startDate: base.startDate,
      endDate: base.endDate,
      priority: base.priority,
      image:
          AnnouncementVisualContent.fromJson(_readRequiredMap(json, 'image')),
      action: _readOptionalAction(json, 'action'),
      dismissingAction: _readOptionalAction(json, 'dismissingAction'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ..._baseTopicJson(this),
      'image': image.toJson(),
      if (action != null) 'action': action!.toJson(),
      if (dismissingAction != null)
        'dismissingAction': dismissingAction!.toJson(),
    };
  }
}

class DialogAnnouncementTopic extends AnnouncementTopic {
  final String title;
  final String message;
  final List<AnnouncementButton> buttons;
  final AnnouncementVisualContent? image;
  final AnnouncementAction? dismissingAction;

  DialogAnnouncementTopic({
    required super.id,
    required super.startDate,
    required super.endDate,
    super.priority,
    required this.title,
    required this.message,
    required this.buttons,
    this.image,
    this.dismissingAction,
  }) : super(type: AnnouncementTopicType.dialog);

  factory DialogAnnouncementTopic.fromJson(Map<String, dynamic> json) {
    final base = _readTopicBaseFields(json);
    return DialogAnnouncementTopic(
      id: base.id,
      startDate: base.startDate,
      endDate: base.endDate,
      priority: base.priority,
      title: _readRequiredString(json, 'title'),
      message: _readRequiredString(json, 'message'),
      buttons: _readRequiredList(json, 'buttons').map((rawButton) {
        if (rawButton is! Map) {
          throw const FormatException(
            'Announcement dialog buttons must be JSON objects.',
          );
        }
        return AnnouncementButton.fromJson(
          Map<String, dynamic>.from(rawButton),
        );
      }).toList(),
      image: _readOptionalMap(json, 'image') == null
          ? null
          : AnnouncementVisualContent.fromJson(
              _readOptionalMap(json, 'image')!),
      dismissingAction: _readOptionalAction(json, 'dismissingAction'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ..._baseTopicJson(this),
      'title': title,
      'message': message,
      'buttons': buttons.map((button) => button.toJson()).toList(),
      if (image != null) 'image': image!.toJson(),
      if (dismissingAction != null)
        'dismissingAction': dismissingAction!.toJson(),
    };
  }
}

class MarqueeAnnouncementTopic extends AnnouncementTopic {
  final String textContent;
  final AnnouncementAction? action;
  final AnnouncementAction? dismissingAction;

  MarqueeAnnouncementTopic({
    required super.id,
    required super.startDate,
    required super.endDate,
    super.priority,
    required this.textContent,
    this.action,
    this.dismissingAction,
  }) : super(type: AnnouncementTopicType.marquee);

  factory MarqueeAnnouncementTopic.fromJson(Map<String, dynamic> json) {
    final base = _readTopicBaseFields(json);
    return MarqueeAnnouncementTopic(
      id: base.id,
      startDate: base.startDate,
      endDate: base.endDate,
      priority: base.priority,
      textContent: _readRequiredString(json, 'textContent'),
      action: _readOptionalAction(json, 'action'),
      dismissingAction: _readOptionalAction(json, 'dismissingAction'),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ..._baseTopicJson(this),
      'textContent': textContent,
      if (action != null) 'action': action!.toJson(),
      if (dismissingAction != null)
        'dismissingAction': dismissingAction!.toJson(),
    };
  }
}

class _AnnouncementTopicBaseFields {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final int? priority;

  const _AnnouncementTopicBaseFields({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.priority,
  });
}

_AnnouncementTopicBaseFields _readTopicBaseFields(Map<String, dynamic> json) {
  return _AnnouncementTopicBaseFields(
    id: _readRequiredString(json, 'id'),
    startDate: DateTime.parse(_readRequiredString(json, 'startDate')),
    endDate: DateTime.parse(_readRequiredString(json, 'endDate')),
    priority: _readOptionalInt(json, 'priority'),
  );
}

AnnouncementTopicType _readTopicType(Map<String, dynamic> json) {
  final value = _readRequiredString(json, 'type');
  switch (value) {
    case 'banner':
      return AnnouncementTopicType.banner;
    case 'modal':
      return AnnouncementTopicType.modal;
    case 'dialog':
      return AnnouncementTopicType.dialog;
    case 'marquee':
      return AnnouncementTopicType.marquee;
    default:
      throw FormatException('Unsupported announcement topic type: $value');
  }
}

AnnouncementActionType _readActionType(Map<String, dynamic> json) {
  final value = _readRequiredString(json, 'actionType');
  switch (value) {
    case 'openLink':
      return AnnouncementActionType.openLink;
    case 'dismissTopic':
      return AnnouncementActionType.dismissTopic;
    default:
      throw FormatException('Unsupported announcement action type: $value');
  }
}

AnnouncementAction? _readOptionalAction(Map<String, dynamic> json, String key) {
  final rawAction = _readOptionalMap(json, key);
  if (rawAction == null) {
    return null;
  }

  return AnnouncementAction.fromJson(rawAction);
}

Map<String, dynamic> _baseTopicJson(AnnouncementTopic topic) {
  return {
    'id': topic.id,
    'type': _topicTypeToJsonValue(topic.type),
    'startDate': topic.startDate.toIso8601String(),
    'endDate': topic.endDate.toIso8601String(),
    if (topic.priority != null) 'priority': topic.priority,
  };
}

String _topicTypeToJsonValue(AnnouncementTopicType type) {
  switch (type) {
    case AnnouncementTopicType.banner:
      return 'banner';
    case AnnouncementTopicType.modal:
      return 'modal';
    case AnnouncementTopicType.dialog:
      return 'dialog';
    case AnnouncementTopicType.marquee:
      return 'marquee';
  }
}

String _actionTypeToJsonValue(AnnouncementActionType type) {
  switch (type) {
    case AnnouncementActionType.openLink:
      return 'openLink';
    case AnnouncementActionType.dismissTopic:
      return 'dismissTopic';
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string.');
  }

  return value;
}

bool _readRequiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('Expected "$key" to be a bool.');
  }

  return value;
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected "$key" to be an int.');
}

bool? _readOptionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is! bool) {
    throw FormatException('Expected "$key" to be a bool.');
  }

  return value;
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('Expected "$key" to be an object.');
  }

  return Map<String, dynamic>.from(value);
}

Map<String, dynamic>? _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is! Map) {
    throw FormatException('Expected "$key" to be an object.');
  }

  return Map<String, dynamic>.from(value);
}

List<dynamic> _readRequiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected "$key" to be a list.');
  }

  return value;
}
