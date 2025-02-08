import 'package:shelf/shelf.dart';

Middleware securityMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;
      
      // List of forbidden patterns
      final forbiddenPatterns = [
        '.env',
        'pubspec',
        '.git',
        '.dart_tool',
        'lib/',
        'bin/',
      ];

      // Check if the requested path contains any forbidden patterns
      if (forbiddenPatterns.any((pattern) => 
          path.toLowerCase().contains(pattern.toLowerCase()))) {
        return Response.forbidden('Access denied');
      }

      // If the path is safe, continue with the request
      return innerHandler(request);
    };
  };
} 