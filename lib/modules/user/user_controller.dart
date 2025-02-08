import 'package:customlabs_backend/middleware/logger_middleware.dart';
import 'package:customlabs_backend/modules/user/user_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:customlabs_backend/service_locator.dart';
import 'package:customlabs_backend/services/firebase_service.dart';
import 'dart:convert';

class UserController {
  final logger = getLogger('UserController');
  final _firebaseService = locator<FirebaseService>();
  final _userRepository = locator<UserRepository>();

  Future<Response> generateTestToken(Request request) async {
    // Only allow in development environment
    if (const String.fromEnvironment('ENVIRONMENT') == 'production') {
      return Response.forbidden('Not available in production');
    }

    try {
        // Get uid from authorization header
      final fbUid = request.headers['fb-uid'];
      if (fbUid == null) {
        return Response.forbidden('Missing or invalid firebase uid');
      }

      logger.info('Generating test token for uid: $fbUid');
      // Create custom token for test user
      final customToken = await _firebaseService.auth.createCustomToken(
        fbUid,
      );

      

      // Exchange custom token for ID token
      

      return Response.ok(
        '{"token": "$customToken"}',
        headers: {
          'content-type': 'application/json',
          'cache-control': 'no-store',
        },
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to generate test token', e, stackTrace);
      return Response.internalServerError(
        body: '{"error": "Failed to generate token"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> createUser(Request request) async {
    try {
      final fbUid = request.headers['fb-uid'];
      if (fbUid == null) {
        return Response.forbidden('Missing or invalid firebase uid');
      }

      // Get Firebase user data
      final firebaseUser = await _firebaseService.auth.getUser(fbUid);

      // Check if user already exists in MySQL database
      final existingUser = await _userRepository.getUserByFirebaseUid(fbUid);
      if (existingUser != null) {
        return Response.badRequest(
          body: {"error": "User already exists"},
          headers: {'content-type': 'application/json'},
        );
      }

      // Check for email / phone / name in body
      final payload = await request.readAsString();
      final userData = jsonDecode(payload);

      final email = userData['email'];  
      final name = userData['name'];

      // Create user in MySQL database
      final user = await _userRepository.createUser(
        firebaseUid: fbUid,
        email: email ?? firebaseUser.email,
        displayName: name ?? firebaseUser.displayName,
      );

      return Response.ok(
        jsonEncode(user.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to create user', e, stackTrace);
      return Response.internalServerError(
        body: '{"error": "Failed to create user"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> getUser(Request request) async {
    try {
      final fbUid = request.headers['fb-uid'];
      if (fbUid == null) {
        return Response.forbidden('Missing or invalid firebase uid');
      }

      // Get user from MySQL database
      final user = await _userRepository.getUserByFirebaseUid(fbUid);
      
      if (user == null) {
        return Response.notFound(
          '{"error": "User not found"}',
          headers: {'content-type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode(user.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to get user', e, stackTrace);
      return Response.internalServerError(
        body: '{"error": "Failed to fetch user data"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> updateUser(Request request) async {
    try {
      final fbUid = request.headers['fb-uid'];
      if (fbUid == null) {
        return Response.forbidden('Missing or invalid firebase uid');
      }

      // Get existing user
      final existingUser = await _userRepository.getUserByFirebaseUid(fbUid);
      if (existingUser == null) {
        return Response.notFound(
          '{"error": "User not found"}',
          headers: {'content-type': 'application/json'},
        );
      }

      // Parse update data
      final payload = await request.readAsString();
      final updateData = jsonDecode(payload);

      // Update user in MySQL database
      final updatedUser = await _userRepository.updateUser(
        fbUid,
        email: updateData['email'],
        displayName: updateData['name'],
      );

      return Response.ok(
        jsonEncode(updatedUser.toJson()),
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to update user', e, stackTrace);
      return Response.internalServerError(
        body: '{"error": "Failed to update user"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  Future<Response> deleteUser(Request request) async {
    try {
      final fbUid = request.headers['fb-uid'];
      if (fbUid == null) {
        return Response.forbidden('Missing or invalid firebase uid');
      }

      // Check if user exists
      final existingUser = await _userRepository.getUserByFirebaseUid(fbUid);
      if (existingUser == null) {
        return Response.notFound(
          '{"error": "User not found"}',
          headers: {'content-type': 'application/json'},
        );
      }

      // Delete user from MySQL database
      await _userRepository.deleteUser(fbUid);
      
      // Optionally, you might want to delete the user from Firebase as well
      // await _firebaseService.auth.deleteUser(fbUid);

      return Response.ok(
        '{"message": "User deleted successfully"}',
        headers: {'content-type': 'application/json'},
      );
    } catch (e, stackTrace) {
      logger.severe('Failed to delete user', e, stackTrace);
      return Response.internalServerError(
        body: '{"error": "Failed to delete user"}',
        headers: {'content-type': 'application/json'},
      );
    }
  }

  
  // Add other user-related endpoints here
}
