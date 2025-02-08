import 'dart:io';

import 'package:customlabs_backend/services/environment_service.dart';
import 'package:dart_firebase_admin/auth.dart';
import 'package:dart_firebase_admin/dart_firebase_admin.dart';
import 'package:logging/logging.dart';

class FirebaseService {
  final EnvService _envService;
  final _log = Logger('FirebaseService');
  late final FirebaseAdminApp _firebaseApp;
  late final Auth _auth;

  FirebaseAdminApp get app => _firebaseApp;
  Auth get auth => _auth;

  FirebaseService(this._envService) {
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      // Initialize Firebase Admin with credentials
      final credential = _envService.get('FIREBASE_CREDENTIALS');
      if (credential == null) {
        throw StateError(
            'Firebase credentials not found in environment variables');
      }

      _firebaseApp = FirebaseAdminApp.initializeApp(
          _envService.get('FIREBASE_PROJECT_ID')!,
          Credential.fromServiceAccount(
              File(_envService.get('FIREBASE_CREDENTIALS')!)));

      _auth = Auth(_firebaseApp);

      _log.info('Firebase Admin initialized successfully');
    } catch (e, stackTrace) {
      _log.severe('Failed to initialize Firebase Admin', e, stackTrace);
      rethrow;
    }
  }

  /// Validates a Firebase ID token and creates user if doesn't exist
  Future<Map<String, dynamic>?> validateToken(String? authHeader) async {
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7); // Remove 'Bearer ' prefix

    try {
      // Verify the Firebase ID token
      final idToken = await _auth.verifyIdToken(token, checkRevoked: true);
      // Return user data including uid
      return {
        'uid': idToken.uid, // Firebase UID
        'email': idToken.email,
        'emailVerified': idToken.emailVerified,
        'phoneNumber': idToken.phoneNumber,
        'picture': idToken.picture,
      };
    } catch (e, stackTrace) {
      _log.warning('Token validation failed', e, stackTrace);
      return null;
    }
  }

  /// Link phone number to user account
  Future<bool> linkPhoneNumber(String uid, String phoneNumber) async {
    try {
      // Update user phone number
      await _auth.updateUser(
            uid,
            UpdateRequest(phoneNumber: phoneNumber),
          );

      // Update custom claims
      final currentClaims = (await getUserClaims(uid)) ?? {};
      currentClaims['phoneVerified'] = true;
      currentClaims['phoneNumber'] = phoneNumber;
      await setUserClaims(uid, currentClaims);

      _log.info('Linked phone number for user: $uid');
      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to link phone number for uid: $uid', e, stackTrace);
      return false;
    }
  }

  /// Link email to user account
  Future<bool> linkEmail(String uid, String email, {String? password}) async {
    try {
      // Update user email
      await _auth.updateUser(
            uid,
            UpdateRequest(email: email, password: password),
          );

      // Update custom claims
      final currentClaims = (await getUserClaims(uid)) ?? {};
      currentClaims['emailLinked'] = true;
      currentClaims['isAnonymous'] = false;
      await setUserClaims(uid, currentClaims);

      _log.info('Linked email for user: $uid');
      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to link email for uid: $uid', e, stackTrace);
      return false;
    }
  }

  /// Get user data from Firebase Auth
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final userRecord = await _auth.getUser(uid);
      final claims = await getUserClaims(uid);

      return {
        'uid': userRecord.uid,
        'email': userRecord.email,
        'phoneNumber': userRecord.phoneNumber,
        'displayName': userRecord.displayName,
        'photoURL': userRecord.photoUrl,
        'emailVerified': userRecord.emailVerified,
        'isAnonymous': claims?['isAnonymous'] ?? true,
        'claims': claims,
        'createdAt': claims?['createdAt'],
      };
    } catch (e, stackTrace) {
      _log.warning('Failed to get user data for uid: $uid', e, stackTrace);
      return null;
    }
  }

  /// Get user custom claims
  Future<Map<String, dynamic>?> getUserClaims(String uid) async {
    try {
      final userRecord = await _auth.getUser(uid);
      return userRecord.customClaims;
    } catch (e, stackTrace) {
      _log.warning('Failed to get claims for uid: $uid', e, stackTrace);
      return null;
    }
  }

  /// Update user custom claims
  Future<bool> setUserClaims(String uid, Map<String, dynamic> claims) async {
    try {
      await _auth.setCustomUserClaims(uid, customUserClaims: claims);
      _log.info('Updated custom claims for user: $uid');
      return true;
    } catch (e, stackTrace) {
      _log.warning('Failed to set custom claims for uid: $uid', e, stackTrace);
      return false;
    }
  }
}
