import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chatbot_service.dart';

/// Modal o pantalla interactiva del Chatbot Asistente de MINER CLC
class ChatbotDialog extends StatefulWidget {
  const ChatbotDialog({super.key, this.initialQuery});

  final String? initialQuery;

  static Future<void> show(BuildContext context, {String? initialQuery}) {
    return showDialog(
      context: context,
      builder: (_) => ChatbotDialog(initialQuery: initialQuery),
    );
  }

  @override
  State<ChatbotDialog> createState() => _ChatbotDialogState();
}

class _ChatbotDialogState extends State<ChatbotDialog> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<ChatbotMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Mensaje inicial de bienvenida
    _messages.add(
      ChatbotMessage(
        text: '¡Hola! ⛑️ Soy tu **Asistente Inteligente de MINER CLC**.\n\nPuedo resolver cualquier duda sobre el funcionamiento del software, límites permisibles de gases, ventilación, protocolos de emergencia y base de datos.\n\n¿En qué puedo ayudarte hoy?',
        isUser: false,
        timestamp: DateTime.now(),
        suggestions: ChatbotService.defaultSuggestions,
      ),
    );

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = (presetText ?? _inputCtrl.text).trim();
    if (text.isEmpty || _isTyping) return;

    // Historial previo (sin el mensaje actual) para dar contexto de seguimiento al LLM
    final history = List<ChatbotMessage>.from(_messages);

    setState(() {
      _messages.add(
        ChatbotMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
      if (presetText == null) {
        _inputCtrl.clear();
      }
    });

    _scrollToBottom();

    final answer = await ChatbotService.instance.askAsync(text, history: history);
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(
        ChatbotMessage(
          text: answer.text,
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: answer.suggestions,
          sources: answer.sources,
          fromLlm: answer.fromLlm,
          fallback: answer.fallback,
          note: answer.note,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _openApiKeyDialog() async {
    await showDialog<void>(context: context, builder: (_) => const _ApiKeyDialog());
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatbotMessage(
          text: 'Conversación reiniciada. ¿En qué más puedo asistirte?',
          isUser: false,
          timestamp: DateTime.now(),
          suggestions: ChatbotService.defaultSuggestions,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF444444)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 720,
        ),
        child: Column(
          children: [
            // ── HEADER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: Color(0xFF383838))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E5B88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4A90D9)),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ASISTENTE MINERO CLC',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3A1A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.green.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'Activo',
                                    style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Soporte técnico, dudas operativas y protocolos mineros',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.vpn_key_rounded,
                      color: ChatbotService.instance.hasApiKey ? Colors.greenAccent : const Color(0xFFFFB74D),
                      size: 20,
                    ),
                    tooltip: 'API Key de Google AI Studio',
                    onPressed: _openApiKeyDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF9E9E9E), size: 20),
                    tooltip: 'Reiniciar conversación',
                    onPressed: _clearChat,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── LISTA DE MENSAJES ──
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A90D9)),
                          ),
                          SizedBox(width: 10),
                          Text('Consultando la base de conocimiento...',
                              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
                        ],
                      ),
                    );
                  }
                  final msg = _messages[index];
                  return _MessageBubble(
                    message: msg,
                    onSuggestionTap: (sug) => _handleSend(sug),
                  );
                },
              ),
            ),

            // ── CHIPS DE SUGERENCIAS RÁPIDAS (ÚLTIMAS) ──
            if (!_isTyping && _messages.isNotEmpty && _messages.last.suggestions.isNotEmpty)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _messages.last.suggestions.length,
                  itemBuilder: (context, i) {
                    final chipText = _messages.last.suggestions[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: const Color(0xFF2C2C2C),
                        side: const BorderSide(color: Color(0xFF4A90D9), width: 0.8),
                        label: Text(
                          chipText,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE0E0E0)),
                        ),
                        onPressed: () => _handleSend(chipText),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 6),

            // ── BARRA DE ENTRADA ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: Color(0xFF383838))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre gases, ventilación, alertas o funcionamiento...',
                        hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF181818),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF444444)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF4A90D9)),
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90D9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _handleSend(),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onSuggestionTap,
  });

  final ChatbotMessage message;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF2E5B88),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4A90D9), width: 1.2),
              ),
              child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2E5B88) : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10).copyWith(
                  bottomRight: isUser ? Radius.zero : const Radius.circular(10),
                  bottomLeft: !isUser ? Radius.zero : const Radius.circular(10),
                ),
                border: Border.all(
                  color: isUser ? const Color(0xFF4A90D9) : const Color(0xFF3D3D3D),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormattedMarkdownText(
                    text: message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFE8E8E8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (!isUser && message.sources.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Fuente: ${message.sources.join(' · ')}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6FA8DC), fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (!isUser && message.fallback) ...[
                    const SizedBox(height: 6),
                    Text(
                      message.note ?? 'Modo local: sin conexión con el modelo de IA.',
                      style: TextStyle(fontSize: 10, color: Color(0xFFFFB74D)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser ? Colors.white70 : const Color(0xFF888888),
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copiado al portapapeles'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF888888)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, top: 2),
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF333333),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

/// Diálogo para pegar la API Key de Google AI Studio (Gemini)
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog();

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final TextEditingController _ctrl = TextEditingController();
  bool _visible = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _ctrl.text.trim();
    if (!ChatbotService.isValidKeyFormat(key)) {
      setState(() => _error = 'Formato inválido. Las claves de Google AI Studio empiezan por "AIza" y no tienen espacios.');
      return;
    }
    await ChatbotService.instance.saveApiKey(key);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    await ChatbotService.instance.saveApiKey('');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final svc = ChatbotService.instance;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Row(
        children: [
          Icon(Icons.vpn_key_rounded, color: Color(0xFF4A90D9), size: 20),
          SizedBox(width: 8),
          Text('API Key de Google AI Studio', style: TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega tu clave de Gemini para activar las respuestas con IA. Créala gratis en aistudio.google.com/apikey.',
              style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (svc.hasApiKey)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Clave actual: ${svc.maskedApiKey}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
              ),
            TextField(
              controller: _ctrl,
              obscureText: !_visible,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle: const TextStyle(color: Color(0xFF757575)),
                errorText: _error,
                errorMaxLines: 3,
                filled: true,
                fillColor: const Color(0xFF181818),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(_visible ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            Text(
              kIsWeb
                  ? 'En la versión web la clave se guarda solo durante esta sesión.'
                  : 'La clave se guarda solo en este equipo (chatbot_settings.json, fuera de Git).',
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        if (svc.hasApiKey) TextButton(onPressed: _remove, child: const Text('Quitar', style: TextStyle(color: Colors.redAccent))),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _FormattedMarkdownText extends StatelessWidget {
  const _FormattedMarkdownText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }
      final boldContent = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldContent,
        style: style.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: style,
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
