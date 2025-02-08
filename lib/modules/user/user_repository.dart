import 'package:customlabs_backend/services/database_service.dart';
import 'package:mysql1/mysql1.dart';

class UserRepository {
  final DatabaseService _db;

  UserRepository(this._db);

  Future<User> createUser({
    required String firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    return await _db.withConnection((conn) async {
      final result = await conn.query(
        'INSERT INTO users (firebase_uid, email, display_name, photo_url, created_at) '
        'VALUES (?, ?, ?, ?, NOW())',
        [firebaseUid, email, displayName, photoUrl],
      );
      
      return User(
        id: result.insertId!,
        firebaseUid: firebaseUid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    });
  }

  Future<User?> getUserByFirebaseUid(String firebaseUid) async {
    return await _db.withConnection((conn) async {
      final results = await conn.query(
        'SELECT * FROM users WHERE firebase_uid = ?',
        [firebaseUid],
      );

      if (results.isEmpty) return null;

      final row = results.first;
      return User.fromRow(row);
    });
  }

  Future<User> updateUser(
    String firebaseUid, {
    String? email,
    String? displayName,
  }) async {
    return await _db.withConnection((conn) async {
      final updates = <String, dynamic>{};
      if (email != null) updates['email'] = email;
      if (displayName != null) updates['display_name'] = displayName;
      
      if (updates.isEmpty) {
        // If no updates, fetch and return current user
        final currentUser = await getUserByFirebaseUid(firebaseUid);
        if (currentUser == null) {
          throw Exception('User not found');
        }
        return currentUser;
      }

      final setClauses = updates.keys
          .map((key) => '$key = ?')
          .join(', ');

      await conn.query(
        'UPDATE users SET $setClauses WHERE firebase_uid = ?',
        [...updates.values, firebaseUid],
      );

      // Fetch and return updated user
      final updatedUser = await getUserByFirebaseUid(firebaseUid);
      if (updatedUser == null) {
        throw Exception('User not found after update');
      }
      return updatedUser;
    });
  }

  Future<void> deleteUser(String firebaseUid) async {
    await _db.withConnection((conn) async {
      final result = await conn.query(
        'DELETE FROM users WHERE firebase_uid = ?',
        [firebaseUid],
      );
      
      if (result.affectedRows == 0) {
        throw Exception('User not found');
      }
    });
  }
}

class User {
  final int id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  User({
    required this.id,
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  factory User.fromRow(ResultRow row) {
    return User(
      id: row['id'] as int,
      firebaseUid: row['firebase_uid'] as String,
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      photoUrl: row['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'firebase_uid': firebaseUid,
    'email': email,
    'display_name': displayName,
    'photo_url': photoUrl,
  };
} 