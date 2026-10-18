import 'dart:async';
import 'dart:math';

import 'models.dart';

/// Almacén de datos simulados en memoria para permitir la ejecución autónoma
/// de MINER CLC sin requerir un servidor PostgreSQL externo en ejecución.
class MockDatabaseStore {
  MockDatabaseStore._() {
    _initializeData();
    _startLiveSimulation();
  }

  static final MockDatabaseStore instance = MockDatabaseStore._();

  static const List<String> zones = [
    "Norte - Nivel 1",
    "Sur - Nivel 2",
    "Este - Nivel 3",
    "Oeste - Nivel 1",
    "Central - Nivel 2",
  ];

  final Map<String, UserAccount> _users = {};
  final Map<String, String> _passwords = {};
  final List<GasReading> _gasReadings = [];
  final List<VentilationState> _ventilation = [];
  final List<MinerAlert> _alerts = [];
  final List<AuditLogEntry> _auditLogs = [];
  final List<BackupEntry> _backups = [];

  Timer? _simTimer;
  final Random _rnd = Random();

  void _initializeData() {
    // 1. Usuarios por defecto
    _users['admin'] = UserAccount(
      id: 'usr_admin',
      username: 'admin',
      displayName: 'Ingeniero de Operaciones',
      email: 'admin@minerclc.com',
      document: '1098765432',
      role: 'administrador',
      isEmailVerified: true,
    );
    _passwords['admin'] = 'admin';

    _users['operador'] = UserAccount(
      id: 'usr_operador',
      username: 'operador',
      displayName: 'Supervisor de Turno',
      email: 'operador@minerclc.com',
      document: '1087654321',
      role: 'supervisor',
      isEmailVerified: true,
    );
    _passwords['operador'] = 'operador';

    _users['minero'] = UserAccount(
      id: 'usr_minero',
      username: 'minero',
      displayName: 'Operador de Frente',
      email: 'minero@minerclc.com',
      document: '1076543210',
      role: 'minero',
      isEmailVerified: true,
    );
    _passwords['minero'] = 'minero';

    // 2. Estado inicial de ventilación para las 5 zonas
    final now = DateTime.now();
    for (final z in zones) {
      _ventilation.add(
        VentilationState(
          zone: z,
          mode: VentMode.auto,
          speed: z.contains('Sur') ? 85 : 70,
          updatedAt: now.subtract(const Duration(minutes: 5)),
        ),
      );
    }

    // 3. Lecturas iniciales históricas (últimos 30 minutos por zona)
    for (int i = 30; i >= 0; i--) {
      final t = now.subtract(Duration(minutes: i));
      for (final z in zones) {
        _gasReadings.add(_generateReadingForZone(z, t));
      }
    }

    // 4. Alertas iniciales
    _alerts.add(
      MinerAlert(
        id: 'ALT-101',
        zone: 'Sur - Nivel 2',
        message: 'Elevación preventiva de CO por tráfico de maquinaria (26.5 ppm)',
        level: 'warn',
        createdAt: now.subtract(const Duration(minutes: 12)),
        resolved: false,
      ),
    );

    _alerts.add(
      MinerAlert(
        id: 'ALT-100',
        zone: 'Este - Nivel 3',
        message: 'Variación transitoria de flujo de aire en chimenea',
        level: 'info',
        createdAt: now.subtract(const Duration(minutes: 45)),
        resolved: true,
        resolvedAt: now.subtract(const Duration(minutes: 30)),
      ),
    );

    // 5. Logs iniciales de auditoría
    _auditLogs.add(
      AuditLogEntry(
        id: 1,
        usuarioId: 'admin',
        accion: 'SISTEMA_INICIADO',
        modulo: 'CORE',
        detalles: 'Arranque del sistema MINER CLC en modo de alta disponibilidad',
        nivel: 'INFO',
        creadoEn: now.subtract(const Duration(hours: 1)),
      ),
    );

    // 6. Respaldos iniciales
    _backups.add(
      BackupEntry(
        id: 1,
        nombreArchivo: 'miner_clc_backup_auto.sql.gz',
        tamanoBytes: 1048576,
        checksumSha256: '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945',
        tipo: 'COMPLETO',
        usuario: 'sistema',
        estado: 'EXITOSO',
        detalles: 'Respaldo programado de seguridad',
        creadoEn: now.subtract(const Duration(days: 1)),
      ),
    );
  }

  GasReading _generateReadingForZone(String zone, DateTime timestamp) {
    // Variación según la zona
    double baseCo = 10.0;
    double baseO2 = 20.8;
    double baseCo2 = 420.0;
    double baseCh4 = 0.25;
    double baseH2s = 1.0;
    double baseTemp = 23.0;

    if (zone.contains('Sur')) {
      baseCo = 25.0; // zona de transporte
      baseTemp = 26.5;
    } else if (zone.contains('Este')) {
      baseCh4 = 0.55; // zona profunda
      baseTemp = 25.0;
    } else if (zone.contains('Oeste')) {
      baseH2s = 2.2;
      baseTemp = 22.0;
    }

    final delta = (_rnd.nextDouble() - 0.5) * 2.0;

    return GasReading(
      zone: zone,
      timestamp: timestamp,
      co: max(1.0, baseCo + delta * 3),
      o2: min(21.2, max(19.6, baseO2 + delta * 0.1)),
      co2: max(350.0, baseCo2 + delta * 30),
      ch4: max(0.05, baseCh4 + delta * 0.1),
      h2s: max(0.2, baseH2s + delta * 0.4),
      temperatura: baseTemp + delta * 0.5,
    );
  }

  /// Inicia el simulador en vivo que genera lecturas continuas cada 4 segundos
  void _startLiveSimulation() {
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final now = DateTime.now();
      for (final z in zones) {
        _gasReadings.insert(0, _generateReadingForZone(z, now));
      }
      // Mantener tamaño razonable en memoria
      if (_gasReadings.length > 500) {
        _gasReadings.removeRange(400, _gasReadings.length);
      }
    });
  }

  // ── MÉTODOS DE ACCESO SIMULADOS ──

  String? tryAuthenticate(String username, String password) {
    final clean = username.trim().toLowerCase();
    if (_users.containsKey(clean)) {
      final storedPass = _passwords[clean] ?? '';
      if (storedPass.isEmpty || storedPass == password || password == 'admin') {
        return _users[clean]!.id;
      }
    }
    // Para facilitar pruebas en modo standalone: cualquier usuario es aceptado
    if (username.trim().isNotEmpty) {
      if (!_users.containsKey(clean)) {
        _users[clean] = UserAccount(
          id: 'usr_$clean',
          username: username,
          displayName: username,
          role: clean.contains('admin') ? 'administrador' : 'minero',
        );
      }
      return _users[clean]!.id;
    }
    return null;
  }

  UserAccount authenticateWithGoogle({
    required String googleId,
    required String email,
    required String name,
    String? photoUrl,
  }) {
    final uname = email.split('@').first;
    final account = UserAccount(
      id: 'google_${googleId.hashCode}',
      username: uname,
      displayName: name,
      email: email,
      googleId: googleId,
      authProvider: 'google',
      photoUrl: photoUrl,
      isEmailVerified: true,
      role: 'minero',
    );
    _users[uname.toLowerCase()] = account;
    return account;
  }

  void createUser({
    required String username,
    required String password,
    required String nombre,
    required String correo,
    required String documento,
  }) {
    final clean = username.trim().toLowerCase();
    _users[clean] = UserAccount(
      id: 'usr_$clean',
      username: username,
      displayName: nombre.isNotEmpty ? nombre : username,
      email: correo.isNotEmpty ? correo : null,
      document: documento.isNotEmpty ? documento : null,
      role: 'minero',
    );
    _passwords[clean] = password;
  }

  void updateUserProfile({
    required String username,
    required String nombre,
    required String correo,
    required String documento,
  }) {
    final clean = username.trim().toLowerCase();
    final existing = _users[clean];
    if (existing != null) {
      _users[clean] = UserAccount(
        id: existing.id,
        username: existing.username,
        displayName: nombre.isNotEmpty ? nombre : existing.displayName,
        email: correo.isNotEmpty ? correo : existing.email,
        document: documento.isNotEmpty ? documento : existing.document,
        googleId: existing.googleId,
        authProvider: existing.authProvider,
        photoUrl: existing.photoUrl,
        isEmailVerified: existing.isEmailVerified,
        role: existing.role,
      );
    }
  }

  void resetPassword({
    required String username,
    required String identificacion,
    required String newPassword,
  }) {
    final clean = username.trim().toLowerCase();
    _passwords[clean] = newPassword;
  }

  List<GasReading> fetchLatestGasReadings({int limit = 200}) {
    return _gasReadings.take(limit).toList();
  }

  List<GasReading> fetchGasHistory({required String zone, int limit = 120}) {
    return _gasReadings
        .where((r) => r.zone.toLowerCase() == zone.toLowerCase())
        .take(limit)
        .toList();
  }

  List<VentilationState> fetchVentilation({int limit = 200}) {
    return List.from(_ventilation);
  }

  void updateVentilation({
    required String zone,
    required VentMode mode,
    required int speed,
  }) {
    final idx = _ventilation.indexWhere((v) => v.zone.toLowerCase() == zone.toLowerCase());
    final state = VentilationState(
      zone: zone,
      mode: mode,
      speed: speed.clamp(0, 100),
      updatedAt: DateTime.now(),
    );
    if (idx >= 0) {
      _ventilation[idx] = state;
    } else {
      _ventilation.add(state);
    }

    logAudit(
      usuarioId: 'operador',
      accion: 'VENTILACION_AJUSTE',
      modulo: 'VENTILACION',
      detalles: 'Zona: $zone, Modo: ${mode.name.toUpperCase()}, Potencia: $speed%',
    );
  }

  List<MinerAlert> fetchAlerts({bool? resolved, String? zone, int limit = 200}) {
    Iterable<MinerAlert> filtered = _alerts;
    if (resolved != null) {
      filtered = filtered.where((a) => a.resolved == resolved);
    }
    if (zone != null && zone.isNotEmpty) {
      filtered = filtered.where((a) => a.zone.toLowerCase() == zone.toLowerCase());
    }
    return filtered.take(limit).toList();
  }

  void createAlert({
    required String zone,
    required String message,
    required String level,
  }) {
    _alerts.insert(
      0,
      MinerAlert(
        id: 'ALT-${_alerts.length + 101}',
        zone: zone,
        message: message,
        level: level,
        createdAt: DateTime.now(),
        resolved: false,
      ),
    );
  }

  void resolveAlert({required String alertId}) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      final old = _alerts[idx];
      _alerts[idx] = MinerAlert(
        id: old.id,
        zone: old.zone,
        message: old.message,
        level: old.level,
        createdAt: old.createdAt,
        resolved: true,
        resolvedAt: DateTime.now(),
      );
    }
  }

  List<AuditLogEntry> fetchAuditLogs({int limit = 50}) {
    return _auditLogs.take(limit).toList();
  }

  void logAudit({
    required String usuarioId,
    required String accion,
    required String modulo,
    String? detalles,
    String nivel = 'INFO',
    String ipOrigen = '127.0.0.1',
  }) {
    _auditLogs.insert(
      0,
      AuditLogEntry(
        id: _auditLogs.length + 1,
        usuarioId: usuarioId,
        accion: accion,
        modulo: modulo,
        detalles: detalles,
        nivel: nivel,
        ipOrigen: ipOrigen,
        creadoEn: DateTime.now(),
      ),
    );
  }

  List<BackupEntry> fetchBackups({int limit = 20}) {
    return _backups.take(limit).toList();
  }

  void registerBackup({
    required String nombreArchivo,
    required int tamanoBytes,
    required String checksumSha256,
    String tipo = 'COMPLETO',
    String usuario = 'sistema',
    String estado = 'EXITOSO',
    String? detalles,
  }) {
    _backups.insert(
      0,
      BackupEntry(
        id: _backups.length + 1,
        nombreArchivo: nombreArchivo,
        tamanoBytes: tamanoBytes,
        checksumSha256: checksumSha256,
        tipo: tipo,
        usuario: usuario,
        estado: estado,
        detalles: detalles,
        creadoEn: DateTime.now(),
      ),
    );
  }

  Map<String, dynamic> getGasStatistics({required String zone, int limitMinutes = 60}) {
    final history = fetchGasHistory(zone: zone, limit: limitMinutes);
    if (history.isEmpty) {
      return {'CO': 0.0, 'O2': 20.9, 'CO2': 400.0, 'CH4': 0.0, 'H2S': 0.0, 'Temp': 22.0};
    }
    double sumCo = 0, sumO2 = 0, sumCo2 = 0, sumCh4 = 0, sumH2s = 0, sumTemp = 0;
    for (final r in history) {
      sumCo += r.co ?? 0;
      sumO2 += r.o2 ?? 20.9;
      sumCo2 += r.co2 ?? 400.0;
      sumCh4 += r.ch4 ?? 0;
      sumH2s += r.h2s ?? 0;
      sumTemp += r.temperatura ?? 22.0;
    }
    final n = history.length;
    return {
      'CO': (sumCo / n).toStringAsFixed(1),
      'O2': (sumO2 / n).toStringAsFixed(1),
      'CO2': (sumCo2 / n).toStringAsFixed(1),
      'CH4': (sumCh4 / n).toStringAsFixed(2),
      'H2S': (sumH2s / n).toStringAsFixed(1),
      'Temp': (sumTemp / n).toStringAsFixed(1),
    };
  }

  void insertGasReading({required GasReading reading}) {
    _gasReadings.insert(0, reading);
  }

  void insertGasReadingsBatch({required List<GasReading> readings}) {
    _gasReadings.insertAll(0, readings);
  }

  int cleanOldReadings({int retentionDays = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final initial = _gasReadings.length;
    _gasReadings.removeWhere((r) => r.timestamp.isBefore(cutoff));
    return initial - _gasReadings.length;
  }
}
