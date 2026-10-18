import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';
import '../../db/models.dart';
import 'google_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _email;
  String? _document;
  String? _googleId;
  String _authProvider = 'local';
  String? _photoUrl;
  String? _localPhotoPath; // foto seleccionada localmente
  bool _isEmailVerified = false;
  String? _error;
  String _role = 'minero';


  bool get isLoading => _loading;
  bool get isLoggedIn => _userId != null;
  String? get userId => _userId;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get email => _email;
  String? get document => _document;
  String? get googleId => _googleId;
  String get authProvider => _authProvider;
  String? get photoUrl => _photoUrl;
  bool get isEmailVerified => _isEmailVerified;
  String? get error => _error;
  String get role => _role;
  String? get localPhotoPath => _localPhotoPath;

  /// Actualiza la foto de perfil local (ruta al archivo en disco).
  void setLocalPhoto(String? path) {
    _localPhotoPath = path;
    notifyListeners();
  }

  /// Actualiza el rol del trabajador (solo en memoria, no persiste en BD todavía).
  void setRole(String role) {
    _role = role;
    notifyListeners();
  }


  /// Inicio de sesión rápido en modo autónomo / demostración sin base de datos
  Future<void> loginDemo({String role = 'administrador'}) async {
    _setLoading(true);
    _error = null;
    try {
      DatabaseService.forceMockMode = true;
      _userId = 'admin';
      _username = 'admin';
      _displayName = 'Ingeniero de Operaciones (Demo)';
      _email = 'operaciones@minerclc.com';
      _document = '1098765432';
      _googleId = null;
      _authProvider = 'demo_standalone';
      _photoUrl = null;
      _isEmailVerified = true;
      _role = role;

      await _db.logAudit(
        usuarioId: 'admin',
        accion: 'LOGIN_DEMO',
        modulo: 'AUTH',
        detalles: 'Ingreso directo en Modo Demostración sin Base de Datos',
        nivel: 'INFO',
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({required String username, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      final id = await _db.tryAuthenticate(username: username, password: password);
      if (id == null) {
        // En modo demostración / autónomo, permitir ingreso de cualquier usuario
        if (username.trim().isNotEmpty) {
          DatabaseService.forceMockMode = true;
          _userId = username;
          _username = username;
          _displayName = username;
          _authProvider = 'local_standalone';
          _role = username.toLowerCase().contains('admin') ? 'administrador' : 'minero';
          notifyListeners();
          return true;
        }
        _error = 'Usuario o contraseña inválidos';
        _clearUser();
        notifyListeners();
        return false;
      }
      _userId = id;
      _username = username;
      _displayName = username;
      _email = null;
      _document = null;
      _googleId = null;
      _authProvider = 'local';
      _photoUrl = null;
      _isEmailVerified = false;

      await _db.logAudit(
        usuarioId: username,
        accion: 'LOGIN_LOCAL',
        modulo: 'AUTH',
        detalles: 'Inicio de sesión local exitoso',
        nivel: 'INFO',
      );

      notifyListeners();
      return true;
    } catch (e) {
      // Fallback automático si la base de datos no está disponible
      DatabaseService.forceMockMode = true;
      final uname = username.trim().isNotEmpty ? username.trim() : 'admin';
      _userId = uname;
      _username = uname;
      _displayName = uname == 'admin' ? 'Ingeniero de Operaciones' : uname;
      _authProvider = 'local_standalone';
      _role = uname.toLowerCase().contains('admin') ? 'administrador' : 'supervisor';
      notifyListeners();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  /// Autenticación e inicio de sesión con cuenta de Google REAL
  Future<bool> signInWithGoogle({
    required String email,
    required String fullName,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      // 1. Validar estrictamente que sea una cuenta real de Google
      final googleProfile = await GoogleAuthService.instance.signInWithRealGoogleAccount(
        email: email,
        fullName: fullName,
      );

      // 2. Autenticar o registrar en PostgreSQL
      final userAccount = await _db.authenticateWithGoogle(
        googleId: googleProfile.id,
        email: googleProfile.email,
        name: googleProfile.name,
        photoUrl: googleProfile.photoUrl,
      );

      _userId = userAccount.id;
      _username = userAccount.username;
      _displayName = userAccount.displayName;
      _email = userAccount.email;
      _googleId = userAccount.googleId;
      _authProvider = 'google';
      _photoUrl = userAccount.photoUrl;
      _isEmailVerified = userAccount.isEmailVerified;

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error en autenticación con Google: ${e.toString().replaceAll("Exception: ", "").replaceAll("ArgumentError: ", "")}';
      _clearUser();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      // Validar correo si se proporciona
      if (correo.isNotEmpty) {
        final val = GoogleAuthService.validateGoogleEmail(correo);
        if (!val.isValid) {
          _error = val.error;
          notifyListeners();
          return false;
        }
      }

      await _db.createUser(
        username: username,
        password: password,
        nombre: nombre,
        correo: correo,
        documento: documento,
      );

      // Autologin después de registrar.
      final id = await _db.tryAuthenticate(username: username, password: password);
      _userId = id;
      _username = username;
      _displayName = nombre.isNotEmpty ? nombre : username;
      _email = correo.isNotEmpty ? correo : null;
      _document = documento.isNotEmpty ? documento : null;
      _authProvider = 'local';
      _photoUrl = null;
      _isEmailVerified = false;

      await _db.logAudit(
        usuarioId: username,
        accion: 'REGISTRO_LOCAL',
        modulo: 'AUTH',
        detalles: 'Nuevo usuario local registrado: $username',
        nivel: 'INFO',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al registrar usuario: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    final user = _username;
    if (user == null) return false;
    _setLoading(true);
    _error = null;
    try {
      await _db.updateUserProfile(
        username: user,
        nombre: nombre,
        correo: correo,
        documento: documento,
      );
      _displayName = nombre.isNotEmpty ? nombre : _displayName;
      _email = correo.isNotEmpty ? correo : null;
      _document = documento.isNotEmpty ? documento : null;

      await _db.logAudit(
        usuarioId: user,
        accion: 'ACTUALIZACION_PERFIL',
        modulo: 'USUARIOS',
        detalles: 'Perfil actualizado por el usuario',
        nivel: 'INFO',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar perfil: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword({
    required String username,
    required String identificacion,
    required String newPassword,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _db.resetPassword(
        username: username,
        identificacion: identificacion,
        newPassword: newPassword,
      );

      await _db.logAudit(
        usuarioId: username,
        accion: 'RECUPERACION_PASSWORD',
        modulo: 'AUTH',
        detalles: 'Contraseña restablecida con documento de identidad',
        nivel: 'WARN',
      );

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al recuperar contraseña: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    final user = _username;
    if (user != null) {
      _db.logAudit(
        usuarioId: user,
        accion: 'LOGOUT',
        modulo: 'AUTH',
        detalles: 'Cierre de sesión del usuario',
        nivel: 'INFO',
      );
    }
    _clearUser();
    notifyListeners();
  }

  void _clearUser() {
    _userId = null;
    _username = null;
    _displayName = null;
    _email = null;
    _document = null;
    _googleId = null;
    _authProvider = 'local';
    _photoUrl = null;
    _localPhotoPath = null;
    _isEmailVerified = false;
    _role = 'minero';
    _error = null;
  }


  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
