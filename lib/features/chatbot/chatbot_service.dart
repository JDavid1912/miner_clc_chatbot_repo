import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'chatbot_knowledge.dart';

class ChatbotAnswer {
  const ChatbotAnswer({
    required this.text,
    required this.suggestions,
    this.matchedTopic,
    this.category = 'General',
    this.sources = const [],
    this.fromLlm = false,
    this.fallback = false,
    this.note,
  });

  final String text;
  final List<String> suggestions;
  final ChatbotTopic? matchedTopic;
  final String category;

  /// Documentos de la base de conocimiento usados por el RAG (solo respuestas del LLM).
  final List<String> sources;

  /// true si la respuesta la generó el LLM (Gemini) vía el backend RAG.
  final bool fromLlm;

  /// true si el backend no respondió y se usó el motor local por palabras clave.
  final bool fallback;

  /// Aviso para el usuario cuando se usó el motor local (p. ej. falta la API key).
  final String? note;
}

class ChatbotMessage {
  ChatbotMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestions = const [],
    this.sources = const [],
    this.fromLlm = false,
    this.fallback = false,
    this.note,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestions;
  final List<String> sources;
  final bool fromLlm;
  final bool fallback;
  final String? note;
}

class ChatbotService {
  ChatbotService._() {
    _loadSettings();
  }
  static final ChatbotService instance = ChatbotService._();

  // ── API Key de Google AI Studio (la pega el usuario en el chatbot) ──
  // Escritorio: se guarda en chatbot_settings.json (excluido de Git).
  // Web: solo en memoria durante la sesión.
  String _apiKey = '';
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Muestra la clave enmascarada, p. ej. AIza••••••••Xk3f
  String get maskedApiKey => _apiKey.length < 10
      ? ''
      : '${_apiKey.substring(0, 4)}••••••••${_apiKey.substring(_apiKey.length - 4)}';

  static final RegExp _keyFormat = RegExp(r'^[A-Za-z0-9_.\-]{20,160}$');
  static bool isValidKeyFormat(String key) => _keyFormat.hasMatch(key.trim());

  File get _settingsFile => File('chatbot_settings.json');

  void _loadSettings() {
    if (kIsWeb) return;
    try {
      if (_settingsFile.existsSync()) {
        final data = jsonDecode(_settingsFile.readAsStringSync()) as Map<String, dynamic>;
        _apiKey = (data['geminiApiKey'] as String?)?.trim() ?? '';
      }
    } catch (_) {}
  }

  /// Guarda (o borra, si viene vacía) la API key de Google AI Studio.
  Future<void> saveApiKey(String key) async {
    _apiKey = key.trim();
    if (kIsWeb) return;
    try {
      await _settingsFile.writeAsString(jsonEncode({'geminiApiKey': _apiKey}), flush: true);
    } catch (_) {}
  }

  /// URL del backend RAG + LLM. Se define al compilar con CHATBOT_API_URL o toma el valor por defecto:
  /// En web local (localhost) apunta al servidor local en puerto 3000. En producción web usa '/api/chat'.
  static const String _apiUrlDefine = String.fromEnvironment('CHATBOT_API_URL', defaultValue: '');
  static String get apiUrl {
    if (_apiUrlDefine.isNotEmpty) return _apiUrlDefine;
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:3000/api/chat';
      }
      return '/api/chat';
    }
    return 'http://localhost:3000/api/chat';
  }

  static const List<String> defaultSuggestions = [
    'Límites de gases permitidos',
    '¿Cómo funciona la ventilación automática?',
    'Protocolo ante alerta de metano (CH4)',
    '¿Cómo inicio con cuenta de Google?',
    '¿Cómo hacer un respaldo de la base de datos?',
    '¿Cómo resolver una alerta activa?',
    '¿Cuáles son las zonas mineras?',
  ];

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Pregunta al LLM (Gemini) a través del backend RAG. Si no hay backend o falla,
  /// responde con el motor local de palabras clave para que el chat nunca quede sin respuesta.
  Future<ChatbotAnswer> askAsync(
    String userQuery, {
    List<ChatbotMessage> history = const [],
  }) async {
    final url = apiUrl;
    if (url.isEmpty) return ask(userQuery);

    try {
      final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
      final payload = jsonEncode({
        'message': userQuery.length > 500 ? userQuery.substring(0, 500) : userQuery,
        'history': recent
            .map((m) => {
                  'role': m.isUser ? 'user' : 'assistant',
                  'text': m.text.length > 800 ? m.text.substring(0, 800) : m.text,
                })
            .toList(),
      });

      final res = await http
          .post(
            Uri.base.resolve(url),
            headers: {
              'Content-Type': 'application/json',
              if (_apiKey.isNotEmpty) 'x-gemini-key': _apiKey,
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 503) {
        return _localWithNote(userQuery, 'Falta la API key de Google AI Studio. Pulsa el ícono 🔑 de arriba para configurarla.');
      }
      if (res.statusCode == 401) {
        return _localWithNote(userQuery, 'La API key no es válida o fue rechazada por Google. Revísala con el ícono 🔑.');
      }
      if (res.statusCode != 200) {
        final errBody = utf8.decode(res.bodyBytes);
        return _localWithNote(userQuery, 'Error HTTP ${res.statusCode}: $errBody');
      }

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final text = (data['answer'] as String?)?.trim() ?? '';
      if (text.isEmpty) throw Exception('Respuesta vacía');

      return ChatbotAnswer(
        text: text,
        suggestions: defaultSuggestions.take(4).toList(),
        sources: ((data['sources'] as List?) ?? const []).map((e) => e.toString()).toList(),
        fromLlm: data['mode'] == 'llm',
        category: 'Asistente IA',
      );
    } catch (e) {
      return _localWithNote(userQuery, 'Modo local: $e');
    }
  }

  ChatbotAnswer _localWithNote(String userQuery, String note) {
    final local = ask(userQuery);
    return ChatbotAnswer(
      text: local.text,
      suggestions: local.suggestions,
      matchedTopic: local.matchedTopic,
      category: local.category,
      fallback: true,
      note: note,
    );
  }

  /// Motor local por palabras clave (respaldo sin conexión al LLM)
  ChatbotAnswer ask(String userQuery) {
    final clean = _normalize(userQuery);

    if (clean.isEmpty) {
      return const ChatbotAnswer(
        text: '¡Hola! Soy el **Asistente Inteligente de MINER CLC**. Puedo ayudarte con dudas sobre el monitoreo de gases, ventilación, alertas, respaldo de datos y funcionamiento del software. ¿En qué te puedo orientar hoy?',
        suggestions: defaultSuggestions,
      );
    }

    // Saludos y cortesías
    final greetings = {'hola', 'buenos dias', 'buenas tardes', 'buenas noches', 'que tal', 'saludos', 'hi', 'hello'};
    if (greetings.contains(clean) || clean.startsWith('hola ') || clean.startsWith('buenas ')) {
      return const ChatbotAnswer(
        text: '¡Hola, colega minero! ⛑️ Estoy aquí para resolver tus dudas operativas o técnicas sobre el sistema **MINER CLC**. Puedes preguntarme sobre valores de gases, ventilación, alertas, respaldos o cuentas de usuario.',
        suggestions: [
          'Límites de gases permitidos',
          '¿Cómo funciona la ventilación automática?',
          '¿Cómo acceder con Google?',
        ],
      );
    }

    // Agradecimientos
    if (clean.contains('gracias') || clean.contains('muchas gracias') || clean.contains('perfecto')) {
      return const ChatbotAnswer(
        text: '¡Con gusto! La seguridad en mina subterránea es nuestra máxima prioridad. Si tienes otra duda sobre el sistema o los sensores, aquí estaré para asistirte.',
        suggestions: [
          '¿Cuáles son las zonas mineras?',
          'Protocolo ante alerta de metano (CH4)',
        ],
      );
    }

    // Búsqueda por coincidencia de temas
    ChatbotTopic? bestMatch;
    int maxScore = 0;

    final queryWords = clean.split(' ').where((w) => w.length > 2).toSet();

    for (final topic in ChatbotKnowledge.topics) {
      int score = 0;

      // Coincidencia por palabras clave
      for (final kw in topic.keywords) {
        final normKw = _normalize(kw);
        if (clean.contains(normKw)) {
          score += 15;
        } else {
          final kwWords = normKw.split(' ');
          for (final kwWord in kwWords) {
            if (queryWords.contains(kwWord)) {
              score += 4;
            }
          }
        }
      }

      // Coincidencia por título o resumen
      final normTitle = _normalize(topic.title);
      if (clean.contains(normTitle) || normTitle.contains(clean)) {
        score += 20;
      }

      for (final w in queryWords) {
        if (normTitle.contains(w)) {
          score += 3;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestMatch = topic;
      }
    }

    // Si encontramos una coincidencia con puntaje suficiente
    if (bestMatch != null && maxScore >= 8) {
      return ChatbotAnswer(
        text: bestMatch.fullResponse,
        suggestions: bestMatch.suggestions,
        matchedTopic: bestMatch,
        category: bestMatch.category,
      );
    }

    // Si no hubo coincidencia precisa, respuesta asistida con recomendaciones
    return ChatbotAnswer(
      text: '''
No encontré una respuesta exacta para tu consulta, pero puedo ayudarte con los siguientes aspectos de **MINER CLC**:

- **Monitoreo de Gases:** Valores y umbrales de CO, O2, CO2, CH4, H2S y temperatura.
- **Sistema de Ventilación:** Modos AUTO y MANUAL, control de potencia 0-100%.
- **Alertas:** Niveles de riesgo y cómo resolverlas en el sistema.
- **Acceso y Google:** Registro con cuenta real de Google y recuperación de contraseñas.
- **Base de Datos y Respaldos:** Generación de copias y logs de auditoría.

*Selecciona una de las opciones sugeridas o reformula tu pregunta con palabras clave como "gases", "ventilación", "metano" o "respaldo".*
''',
      suggestions: defaultSuggestions.take(4).toList(),
      category: 'Ayuda General',
    );
  }
}