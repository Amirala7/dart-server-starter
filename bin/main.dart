import 'dart:async';
import 'dart:io';
import 'package:customlabs_backend/services/database_service.dart';
import 'package:customlabs_backend/services/environment_service.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:customlabs_backend/middleware/auth_middleware.dart';
import 'package:customlabs_backend/middleware/logger_middleware.dart';
import 'package:customlabs_backend/service_locator.dart';
import 'package:customlabs_backend/routes/api_router.dart';
import 'package:customlabs_backend/middleware/security_middleware.dart';
import 'package:customlabs_backend/middleware/cors_middleware.dart';

Future<void> main() async {
  // Initialize logger first
  final loggerService = LoggerService();
  await loggerService.setupLogger();
  final log = getLogger('Server');

  // Initialize error handling for uncaught errors
  await _initializeErrorHandling();

  log.info('Starting server initialization...');

  try {
    // Setup service locator
    await _initializeServices(log);

    // Initialize database connection
    await _initializeDatabase(log);

    // Create server handler with middleware pipeline
    final handler = await _createHandler(log);

    // Start the server
    final server = await _startServer(handler, log);

    // Set up graceful shutdown
    await _setupGracefulShutdown(server, log);

    log.info('Server initialization completed successfully');
  } catch (e, stackTrace) {
    log.severe('Fatal error during server initialization', e, stackTrace);
    await _performCleanShutdown(log);
    exit(1);
  }
}

Future<void> _initializeErrorHandling() async {
  // Handle all uncaught errors in the zone
  runZonedGuarded(() async {
    // Your application code will run in this zone
  }, (error, stackTrace) {
    final log = getLogger('UncaughtError');
    log.severe('Uncaught error', error, stackTrace);
  });
}

Future<void> _initializeServices(Logger log) async {
  log.info('Initializing services...');
  setupServiceLocator();
  
  // Verify critical services
  final envService = locator<EnvService>();
  if (!await _verifyEnvironmentVariables(envService)) {
    throw StateError('Required environment variables are missing');
  }
}

Future<bool> _verifyEnvironmentVariables(EnvService envService) {
  final requiredVars = [
    'AUTH_TOKEN',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CREDENTIALS',
    // Add other required environment variables
  ];

  final missingVars = requiredVars
      .where((variable) => envService.get(variable)?.isEmpty ?? true)
      .toList();

  if (missingVars.isNotEmpty) {
    throw StateError('Missing required environment variables: $missingVars');
  }

  return Future.value(true);
}

Future<void> _initializeDatabase(Logger log) async {
  log.info('Initializing database connection pool...');
  try {
    final dbService = locator<DatabaseService>();
    final envService = locator<EnvService>();
    
    await dbService.initialize(envService);
    
    // Test the connection pool with a simple query
    await dbService.withConnection((conn) async {
      await conn.query('SELECT 1');
    });
    
    log.info('Database connection pool established successfully');
  } catch (e, stackTrace) {
    log.severe('Database initialization failed', e, stackTrace);
    throw StateError('Failed to initialize database pool: $e');
  }
}

Future<Handler> _createHandler(Logger log) async {
  log.info('Setting up middleware and routes...');
  
  // Health check handler
  Response healthCheck(Request request) => Response.ok(
    '{"status": "healthy", "timestamp": "${DateTime.now().toIso8601String()}"}',
    headers: {'content-type': 'application/json'},
  );

  final router = ApiRouter().router;
  router.get('/health', healthCheck);

  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(securityMiddleware())
      .addMiddleware(authMiddleware())
      .addHandler(router.call);
}

Future<HttpServer> _startServer(Handler handler, Logger log) async {
  final port = int.parse(locator<EnvService>().get('PORT') ?? '8080');
  final address = InternetAddress.anyIPv4;

  log.info('Starting server on port $port...');
  
  try {
    final server = await shelf_io.serve(
      handler,
      address,
      port,
      shared: true, // Enable multiple instances if needed
    );

    server.autoCompress = true;
    log.info('Server listening on http://${server.address.host}:${server.port}');
    return server;
  } catch (e, stackTrace) {
    log.severe('Failed to start server', e, stackTrace);
    throw StateError('Could not start server: $e');
  }
}

Future<void> _setupGracefulShutdown(HttpServer server, Logger log) async {
  final signals = [
    ProcessSignal.sigint,
    ProcessSignal.sigterm,
  ];

  for (final signal in signals) {
    signal.watch().listen((sig) async {
      log.info('Received signal $sig - initiating graceful shutdown...');
      await _performCleanShutdown(log, server: server);
      exit(0);
    });
  }
}

Future<void> _performCleanShutdown(Logger log, {HttpServer? server}) async {
  log.info('Performing clean shutdown...');
  
  if (server != null) {
    await server.close(force: false);
    log.info('Server stopped accepting new connections');
  }

  try {
    // Close database connections
    await locator<DatabaseService>().close();
    log.info('Database connections closed');

    // Add other cleanup tasks here
    // e.g., close message queues, clear caches, etc.

  } catch (e, stackTrace) {
    log.severe('Error during shutdown', e, stackTrace);
  } finally {
    log.info('Shutdown complete');
  }
} 