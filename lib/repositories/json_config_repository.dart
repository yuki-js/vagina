import 'package:vagina/interfaces/config_repository.dart';
import 'package:vagina/interfaces/key_value_store.dart';
import 'package:logging/logging.dart';

/// JSON-based implementation of ConfigRepository
class JsonConfigRepository implements ConfigRepository {
  static final Logger _logger = Logger('JsonConfigRepository');

  final KeyValueStore _store;

  JsonConfigRepository(this._store);

  @override
  Future<void> clearAll() async {
    _logger.info('Clearing all configuration');
    await _store.clear();
  }

  @override
  Future<String> getConfigFilePath() async {
    return await _store.getFilePath();
  }
}
