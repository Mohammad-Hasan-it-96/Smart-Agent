import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import '../db/database_helper.dart';

class BackupService {
  static const String _backupFileName = 'smart_agent_backup.db';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: _scopes,
  );

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return path.join(dbPath, 'smart_agent.db');
  }

  /// Sign in to Google account
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      print('Google Sign-In error: $e');
      // Check for specific error codes
      if (e.toString().contains('ApiException: 10')) {
        throw Exception(
          'خطأ في إعدادات Google Sign-In. يرجى التأكد من:\n'
          '1. إضافة SHA-1 في Google Cloud Console\n'
          '2. إنشاء OAuth 2.0 Client ID\n'
          '3. تفعيل Google Drive API',
        );
      }
      rethrow;
    }
  }

  /// Sign out from Google account
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google Sign-Out error: $e');
    }
  }

  /// Get authenticated HTTP client for Google APIs
  Future<http.Client> _getAuthenticatedClient() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) {
      throw Exception('يجب تسجيل الدخول إلى حساب Google أولاً');
    }

    // Get auth headers from Google Sign-In
    final authHeaders = await account.authHeaders;

    // Create a client that adds auth headers to requests
    return _AuthenticatedClient(authHeaders);
  }

  /// Backup database to Google Drive
  Future<void> backupToGoogleDrive() async {
    try {
      // Ensure user is signed in
      var account = await _googleSignIn.signInSilently();
      if (account == null) {
        account = await signIn();
        if (account == null) {
          throw Exception('تم إلغاء تسجيل الدخول');
        }
      }

      // Get database file
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('ملف قاعدة البيانات غير موجود');
      }

      // Get authenticated client
      final client = await _getAuthenticatedClient();
      final driveApi = drive.DriveApi(client);

      // Read database file
      final fileBytes = await dbFile.readAsBytes();

      // Create file metadata
      final fileMetadata = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder']; // Store in app-specific folder

      // Check if backup already exists and delete it
      try {
        final existingFiles = await driveApi.files.list(
          q: "name='$_backupFileName' and 'appDataFolder' in parents",
          spaces: 'appDataFolder',
        );

        if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
          for (final file in existingFiles.files!) {
            await driveApi.files.delete(file.id!);
          }
        }
      } catch (e) {
        // Ignore if file doesn't exist
        print('No existing backup found: $e');
      }

      // Upload file
      final media = drive.Media(
        Stream.value(fileBytes),
        fileBytes.length,
        contentType: 'application/x-sqlite3',
      );

      await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      client.close();
    } catch (e) {
      print('Backup error: $e');
      rethrow;
    }
  }

  /// Restore database from Google Drive
  Future<void> restoreFromGoogleDrive() async {
    try {
      // Ensure user is signed in
      var account = await _googleSignIn.signInSilently();
      if (account == null) {
        account = await signIn();
        if (account == null) {
          throw Exception('تم إلغاء تسجيل الدخول');
        }
      }

      // Get authenticated client
      final client = await _getAuthenticatedClient();
      final driveApi = drive.DriveApi(client);

      // Find backup file
      final files = await driveApi.files.list(
        q: "name='$_backupFileName' and 'appDataFolder' in parents",
        spaces: 'appDataFolder',
      );

      if (files.files == null || files.files!.isEmpty) {
        client.close();
        throw Exception('لا توجد نسخة احتياطية على Google Drive');
      }

      final backupFile = files.files!.first;
      if (backupFile.id == null) {
        client.close();
        throw Exception('خطأ في العثور على النسخة الاحتياطية');
      }

      // Download backup file
      final stream = await driveApi.files.get(
        backupFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Read file bytes
      final fileBytes = <int>[];
      await for (final chunk in stream.stream) {
        fileBytes.addAll(chunk);
      }

      // Close database connection before replacing
      await DatabaseHelper.instance.close();

      // Get database path
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      // Backup current database (just in case)
      if (await dbFile.exists()) {
        final backupPath = '${dbPath}.old';
        await dbFile.copy(backupPath);
      }

      // Write restored database
      await dbFile.writeAsBytes(fileBytes);

      // Reset and reinitialize database connection
      DatabaseHelper.resetInstance();
      await DatabaseHelper.instance.database;

      client.close();
    } catch (e) {
      print('Restore error: $e');
      rethrow;
    }
  }

  /// Check if user is signed in
  Future<bool> isSignedIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (e) {
      return false;
    }
  }

  /// Get current user email
  Future<String?> getCurrentUserEmail() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return account?.email;
    } catch (e) {
      return null;
    }
  }
}

/// Custom HTTP client that adds authentication headers
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Add auth headers to the request
    _headers.forEach((key, value) {
      request.headers[key] = value;
    });
    return request.send();
  }
}
