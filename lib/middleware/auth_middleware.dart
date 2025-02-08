import 'package:customlabs_backend/service_locator.dart';
import 'package:customlabs_backend/services/firebase_service.dart';
import 'package:customlabs_backend/services/environment_service.dart';
import 'package:shelf/shelf.dart';
import 'package:logging/logging.dart';

Middleware authMiddleware() {
  final log = Logger('AuthMiddleware');
  final envService = locator<EnvService>();
  
  return (Handler innerHandler) {
    return (Request request) async {
        log.info('Request: ${request.method} ${request.url}');
        log.info('Environment: ${envService.get('ENVIRONMENT')}');
      if (envService.get('ENVIRONMENT') != 'production' && request.url.path == 'dev/token') {
        log.info('Skipping authentication for development token request');
        return innerHandler(request);
      }

      final authService = locator<FirebaseService>();
      final authHeader = request.headers['authorization'];
      
      try {
        // Validate token and create user if needed
        final userInfo = await authService.validateToken(authHeader);
        
        if (userInfo == null) {
          log.warning('Invalid or missing token in request');
          return Response.unauthorized('Invalid or missing authentication token');
        }

        // Add user data to request context
        final updatedRequest = request.change(context: {
          'firebaseUserInfo': userInfo,
        });
        return innerHandler(updatedRequest);
      } catch (e, stackTrace) {
        log.severe('Authentication error', e, stackTrace);
        return Response.internalServerError(
          body: 'An error occurred during authentication',
        );
      }
    };
  };
} 