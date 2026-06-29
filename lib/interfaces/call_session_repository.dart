import 'package:vagina/models/call_session.dart';

class CallSessionPage {
  final List<CallSession> items;
  final String? nextCursor;

  const CallSessionPage({
    required this.items,
    required this.nextCursor,
  });
}

/// Repository for retrieving and deleting server-backed call session history.
abstract class CallSessionRepository {
  /// List call sessions using the server cursor pagination contract.
  Future<CallSessionPage> list({String? cursor, int? limit});

  /// Get a specific call session detail by ID.
  Future<CallSession?> getById(String id);

  /// Delete a call session.
  Future<bool> delete(String id);

  /// Bulk-delete call sessions and return the server deleted count.
  Future<int> bulkDelete(List<String> ids);
}
