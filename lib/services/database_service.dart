import 'package:mysql1/mysql1.dart';
import 'package:logging/logging.dart';
import 'package:customlabs_backend/services/environment_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  final _logger = Logger('DatabaseService');
  late List<MySqlConnection> _pool;
  late ConnectionSettings _settings;
  late final int _poolSize;  // Adjust based on your needs
  int _currentConnection = 0;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<void> initialize(EnvService envService) async {
    _poolSize = int.parse(envService.get('DB_POOL_SIZE') ?? '10');
    final dbHost = envService.get('DB_HOST') ?? 'localhost';
    final dbPort = int.parse(envService.get('DB_PORT') ?? '3306');
    final dbUser = envService.get('DB_USER');
    final dbPassword = envService.get('DB_PASSWORD');
    final dbName = envService.get('DB_NAME');

    if (dbUser == null || dbPassword == null || dbName == null) {
      throw StateError('Database environment variables are not properly set');
    }

    _settings = ConnectionSettings(
      host: dbHost,
      port: dbPort,
      user: dbUser,
      password: dbPassword,
      db: dbName,
    );

    // Initialize the connection pool
    _pool = [];
    for (var i = 0; i < _poolSize; i++) {
      try {
        final conn = await MySqlConnection.connect(_settings);
        _pool.add(conn);
      } catch (e) {
        _logger.severe('Failed to create database connection: $e');
        throw StateError('Could not initialize database pool');
      }
    }

    _logger.info('Database pool initialized with $_poolSize connections');
  }

  Future<T> withConnection<T>(Future<T> Function(MySqlConnection) operation) async {
    // Simple round-robin connection selection
    final conn = _pool[_currentConnection];
    _currentConnection = (_currentConnection + 1) % _poolSize;

    try {
      // Test if connection is still alive
      await conn.query('SELECT 1');
      return await operation(conn);
    } catch (e) {
      _logger.warning('Connection failed, attempting to reconnect...');
      // Try to reconnect
      try {
        final newConn = await MySqlConnection.connect(_settings);
        _pool[_currentConnection] = newConn;
        return await operation(newConn);
      } catch (e) {
        _logger.severe('Database operation failed: $e');
        rethrow;
      }
    }
  }

  Future<void> close() async {
    _logger.info('Closing database pool...');
    for (var conn in _pool) {
      await conn.close();
    }
    _pool.clear();
    _logger.info('Database pool closed');
  }
} 