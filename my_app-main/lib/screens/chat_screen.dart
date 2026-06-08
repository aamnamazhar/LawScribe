import 'dart:convert';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/services/chat_store.dart';
import 'package:my_app/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../components/chat_bubble.dart';
import '../components/message_input.dart';
import '../components/scribe_logo.dart';
// import '../components/appbar_hover_icon.dart';
import '../components/hover_icon.dart';
import '../theme_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/blockchain_verify_screen.dart';
import '../data/clause_info.dart';

// Clause metadata (plain names, risk levels, categories) lives in
// ../data/clause_info.dart so it can be shared with the PDF report builder.


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String currentUserName = 'user';
  final ScrollController _scrollController = ScrollController();
  bool isTyping = false;
  String? currentDocumentPath;
  String? currentDocId;
  String? currentBlockchainTx;
  String? _uploadedFileName;
  bool _showScrollFab = false;

  // Firestore id of the conversation being persisted. Null until the first
  // message creates the chat (or until a past chat is opened from the drawer).
  String? _chatId;
  bool _routeArgsHandled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If we were opened with a chatId argument, load that conversation once.
    if (_routeArgsHandled) return;
    _routeArgsHandled = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _loadChat(args);
    }
  }

  /// Load a previously saved chat: restore its messages and document context.
  Future<void> _loadChat(String chatId) async {
    final meta = await ChatStore.loadChatMeta(chatId);
    final loaded = await ChatStore.loadMessages(chatId);
    if (!mounted) return;
    setState(() {
      _chatId = chatId;
      if (meta != null) {
        currentDocId = meta['docId'] as String?;
        currentDocumentPath = meta['docPath'] as String?;
        currentBlockchainTx = meta['blockchainTx'] as String?;
        _uploadedFileName = meta['docName'] as String?;
      }
      if (loaded.isNotEmpty) {
        messages
          ..clear()
          ..addAll(loaded.map((m) => Map<String, dynamic>.from(m)));
      }
    });
    _scrollToBottom();
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  /// Ensure a chat document exists, creating one on first use.
  Future<String?> _ensureChat({String? title}) async {
    _chatId ??= await ChatStore.createChat(
      title: title,
      docId: currentDocId,
      docName: _uploadedFileName,
      docPath: currentDocumentPath,
    );
    return _chatId;
  }

  /// Persist a message and refresh the chat's metadata (preview + doc context).
  Future<void> _saveMessage(
    Map<String, dynamic> message, {
    String? title,
    String? lastMessage,
  }) async {
    final id = await _ensureChat(title: title);
    if (id == null) return; // signed out or write rejected
    await ChatStore.addMessage(id, message);
    await ChatStore.updateMeta(id, {
      'lastMessage': ?lastMessage,
      if (currentDocId != null) 'docId': currentDocId,
      if (_uploadedFileName != null) 'docName': _uploadedFileName,
      if (currentDocumentPath != null) 'docPath': currentDocumentPath,
      if (currentBlockchainTx != null) 'blockchainTx': currentBlockchainTx,
    });
  }

  /// Short, human-friendly title derived from the first user message.
  String _titleFrom(String text) {
    final t = text.trim().replaceAll('\n', ' ');
    return t.length <= 40 ? t : '${t.substring(0, 40)}…';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 120;
    if (_showScrollFab == atBottom) {
      setState(() => _showScrollFab = !atBottom);
    }
  }

  // Starts empty: the welcome hero is the greeting. Once the user sends a
  // message, the conversation begins with no leftover canned greeting bubble.
  final List<Map<String, dynamic>> messages = [];

  Future<void> sendMessage(
    String text,
    PlatformFile? file,
    String? audioPath,
  ) async {
    if (text.trim().isEmpty && file == null) return;
    final time = _formatTime(DateTime.now());

    setState(() {
      if (text.trim().isNotEmpty) {
        messages.add({
          'sender': 'user',
          'type': 'text',
          'text': text,
          'time': time,
        });
      }
      if (file != null) {
        messages.add({
          'sender': 'user',
          'type': 'file',
          'fileName': file.name,
          'fileSize': (file.size / 1024).toStringAsFixed(1),
          'time': time,
        });
        isTyping = true;
      }
    });

    _scrollToBottom();

    // Persist the user's message(s) so the conversation survives a restart.
    if (text.trim().isNotEmpty) {
      await _saveMessage(
        {'sender': 'user', 'type': 'text', 'text': text, 'time': time},
        title: _titleFrom(text),
        lastMessage: text,
      );
    }
    if (file != null) {
      await _saveMessage(
        {
          'sender': 'user',
          'type': 'file',
          'fileName': file.name,
          'fileSize': (file.size / 1024).toStringAsFixed(1),
          'time': time,
        },
        title: file.name,
        lastMessage: '📎 ${file.name}',
      );
    }

    if (file != null && file.path != null) {
      try {
        final response = await ApiService.uploadDocument(file.path!);
        final responseBody = await response.stream.bytesToString();

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          currentDocumentPath = data["file"]["path"];
          currentDocId = data["file"]["hash"];
          currentBlockchainTx = data["file"]["blockchain_tx"];
          _uploadedFileName = file.name;

          final uploadMsg = {
            'sender': 'ai',
            'type': 'text',
            'text':
                'Document uploaded successfully.\n'
                'How can I help you with it?\n'
                'Try: summarize, detect clauses, or ask any question about the document.',
            'time': _formatTime(DateTime.now()),
            'showVerify': true,
            'docId': currentDocId,
            'blockchainTx': currentBlockchainTx,
          };
          setState(() {
            isTyping = false;
            messages.add(uploadMsg);
          });
          await _saveMessage(uploadMsg, lastMessage: 'Document uploaded');
        } else {
          setState(() {
            isTyping = false;
            messages.add({
              'sender': 'ai',
              'type': 'text',
              'text': 'Upload failed: $responseBody',
              'time': _formatTime(DateTime.now()),
            });
          });
        }

        _scrollToBottom();
        return;
      } catch (e) {
        if (!mounted) return;

        setState(() {
          isTyping = false;
          messages.add({
            'sender': 'ai',
            'type': 'text',
            'text': 'Error uploading document: $e',
            'time': _formatTime(DateTime.now()),
          });
        });

        _scrollToBottom();
        return;
      }
    }

    if (text.trim().isNotEmpty && currentDocId != null && currentDocumentPath != null) {
      await _handleDocumentQuery(text.trim());
    } else if (text.trim().isNotEmpty) {
      await _handleGeneralQuery(text.trim());
    }
  }

  /// Turn an exception into a short, human-readable message so the chat never
  /// shows a raw stack trace — and never a blank bubble.
  String _errorText(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection') ||
        s.contains('ClientException') ||
        s.contains('timed out') ||
        s.contains('TimeoutException')) {
      return "⚠️ Couldn't reach the server. Make sure the backend is running "
          "and your device is on the same network, then try again.";
    }
    return "⚠️ Something went wrong. Please try again.";
  }

  Future<void> _handleDocumentQuery(String userText) async {
    setState(() => isTyping = true);
    _scrollToBottom();

    try {
      final lowerText = userText.toLowerCase();

      final bool isSummary = lowerText.contains("summary") ||
          lowerText.contains("summarize") ||
          lowerText.contains("summarise");

      final bool isClauses = lowerText.contains("clause") ||
          lowerText.contains("clauses") ||
          lowerText.contains("detect");

      final bool isInsights = lowerText.contains("insight") ||
          lowerText.contains("explain clauses") ||
          lowerText.contains("what do the clauses mean");

      // ── Streaming path: summary & general Q&A ────────────────────────
      if (isSummary || (!isClauses && !isInsights)) {
        final stream = isSummary
            ? ApiService.getSummaryStream(currentDocId!)
            : ApiService.queryDocumentStream(currentDocId!, userText);

        // Keep the typing indicator until the first token, then fill a bubble
        // word-by-word — no blank bubble while waiting.
        int? msgIndex;
        await for (final token in stream) {
          if (!mounted) break;
          if (msgIndex == null) {
            msgIndex = messages.length;
            setState(() {
              isTyping = false;
              messages.add({
                'sender': 'ai',
                'type': 'text',
                'text': token,
                'time': _formatTime(DateTime.now()),
              });
            });
          } else {
            final idx = msgIndex;
            setState(() {
              messages[idx]['text'] =
                  (messages[idx]['text'] as String) + token;
            });
          }
          _scrollToBottom();
        }
        if (!mounted) return;

        if (msgIndex == null) {
          setState(() {
            isTyping = false;
            messages.add({
              'sender': 'ai',
              'type': 'text',
              'text':
                  "I couldn't generate a response for that. Please try again.",
              'time': _formatTime(DateTime.now()),
            });
          });
          _scrollToBottom();
          return;
        }

        // Persist the completed answer once streaming finishes.
        final finalText = messages[msgIndex]['text'] as String;
        await _saveMessage(
          Map<String, dynamic>.from(messages[msgIndex]),
          lastMessage: finalText,
        );

        _scrollToBottom();
        return;
      }

      // ── Non-streaming path: clauses & insights (structured JSON) ─────
      String aiResponse;

      if (isClauses) {
        final clauses = await ApiService.getClauses(currentDocId!);
        aiResponse = _formatClausesResponse(clauses);
      } else {
        // insights
        final insights = await ApiService.getInsights(currentDocId!);
        if (insights.isEmpty) {
          aiResponse = "No clause insights available for this document.";
        } else {
          final lines = insights.map((i) =>
              "📌 ${i['clause_type']}\n${i['insight']}").join("\n\n");
          aiResponse = lines;
        }
      }

      if (!mounted) return;

      final aiMsg = {
        'sender': 'ai',
        'type': 'text',
        'text': aiResponse,
        'time': _formatTime(DateTime.now()),
      };
      setState(() {
        isTyping = false;
        messages.add(aiMsg);
      });
      await _saveMessage(aiMsg, lastMessage: aiResponse);

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isTyping = false;
        messages.add({
          'sender': 'ai',
          'type': 'text',
          'text': _errorText(e),
          'time': _formatTime(DateTime.now()),
        });
      });

      _scrollToBottom();
    }
  }

  /// Turn the raw clause-detection response into a layman-friendly,
  /// grouped summary with risk dots and plain-English explanations.
  String _formatClausesResponse(List<dynamic> clauses) {
    if (clauses.isEmpty) {
      return "I scanned your document but couldn't identify any specific legal "
          "clauses. Try asking me a question about it instead.";
    }

    // Separate high-risk items from the rest
    final List<Map<String, dynamic>> redFlags = [];
    final List<Map<String, dynamic>> others = [];

    for (final c in clauses) {
      final type = c['clause_type'] as String;
      final info = clauseInfo[type];
      final entry = {
        'type': type,
        'confidence': c['confidence'],
        'info': info,
      };
      if (info?.risk == 'high') {
        redFlags.add(entry);
      } else {
        others.add(entry);
      }
    }

    final buffer = StringBuffer();
    final count = clauses.length;

    // ── Quick verdict ──
    if (redFlags.isEmpty) {
      buffer.writeln('✅ Looks clean — $count clauses found, nothing high-risk.\n');
    } else {
      buffer.writeln(
        '⚠️ Found $count clauses — ${redFlags.length} need your attention.\n',
      );
    }

    // ── Red flags first (if any) ──
    if (redFlags.isNotEmpty) {
      buffer.writeln('🔴 WATCH OUT FOR:');
      for (final item in redFlags) {
        final info = item['info'] as ClauseInfo?;
        final name = info?.plainName ?? item['type'] as String;
        final desc = info?.layExplanation ?? '';
        buffer.writeln('  • $name');
        if (desc.isNotEmpty) buffer.writeln('    $desc');
      }
      buffer.writeln();
    }

    // ── Everything else as a simple bullet list ──
    if (others.isNotEmpty) {
      buffer.writeln('Also found:');
      for (final item in others) {
        final info = item['info'] as ClauseInfo?;
        final name = info?.plainName ?? item['type'] as String;
        buffer.writeln('  • $name');
      }
      buffer.writeln();
    }

    buffer.write(
      '💡 Want details? Type "give me insights" and I\'ll explain '
      'what each clause actually says in your contract.',
    );

    return buffer.toString();
  }

  /// Answer a general legal question when no document is loaded — streams a
  /// hybrid response (grounded in LawScribe's clause definitions when relevant,
  /// otherwise the model's general knowledge).
  Future<void> _handleGeneralQuery(String userText) async {
    // Keep the typing indicator visible until the first token arrives, then
    // swap it for a real bubble that fills word-by-word (no blank bubble).
    setState(() => isTyping = true);
    _scrollToBottom();

    int? msgIndex;

    try {
      final stream = ApiService.generalQueryStream(userText);

      await for (final token in stream) {
        if (!mounted) break;
        if (msgIndex == null) {
          msgIndex = messages.length;
          setState(() {
            isTyping = false;
            messages.add({
              'sender': 'ai',
              'type': 'text',
              'text': token,
              'time': _formatTime(DateTime.now()),
            });
          });
        } else {
          final idx = msgIndex;
          setState(() {
            messages[idx]['text'] =
                (messages[idx]['text'] as String) + token;
          });
        }
        _scrollToBottom();
      }
      if (!mounted) return;

      if (msgIndex == null) {
        // Stream produced nothing — show a notice, never silence.
        setState(() {
          isTyping = false;
          messages.add({
            'sender': 'ai',
            'type': 'text',
            'text': "I couldn't generate a response for that. Please try again.",
            'time': _formatTime(DateTime.now()),
          });
        });
        _scrollToBottom();
        return;
      }

      final finalText = messages[msgIndex]['text'] as String;
      await _saveMessage(
        Map<String, dynamic>.from(messages[msgIndex]),
        lastMessage: finalText,
      );

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isTyping = false;
        messages.add({
          'sender': 'ai',
          'type': 'text',
          'text': _errorText(e),
          'time': _formatTime(DateTime.now()),
        });
      });

      _scrollToBottom();
    }
  }

  String _formatTime(DateTime now) {
    final h = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;
    return '$h:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 150,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Snackbars ──────────────────────────────────────────────────────────────

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Color(0xFF6BCB77),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.textPrimary, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: context.popupColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: const Color(0xFF6BCB77).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: context.accent,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.textPrimary, fontSize: 13.5),
              ),
            ),
          ],
        ),
        backgroundColor: context.popupColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: context.accent.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Edit dialog ────────────────────────────────────────────────────────────

  void _showEditDialog(int index) {
    final controller = TextEditingController(
      text: messages[index]['text'] ?? '',
    );
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Message',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 5,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.borderColor,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.borderColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.accent,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => messages[index]['text'] = controller.text);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.accent, context.accentSecondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: context.heroShadow,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Color(0xFF0A0A14),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Welcome hero (empty state) ──────────────────────────────────────────

  Widget _buildWelcomeHero(BuildContext context) {
    // Centered when there's room; scrolls instead of overflowing when the
    // keyboard shrinks the available height.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
            // Logo icon with pulse glow
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.accent, context.accentSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: context.heroShadow,
              ),
              child: Center(
                child: ScribeMark(
                  size: 36,
                  color: context.isDark
                      ? const Color(0xFF0A0A14)
                      : Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Welcome to LawScribe',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Your AI-powered legal assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 32),

            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload a contract',
                  onTap: () {
                    // Trigger the file picker from the message input
                    // We send an empty message with a null file to signal pick
                    _pickFileDirectly();
                  },
                ),
                _SuggestionChip(
                  icon: Icons.help_outline_rounded,
                  label: 'What can you do?',
                  onTap: () => sendMessage('What can you do?', null, null),
                ),
                _SuggestionChip(
                  icon: Icons.gavel_rounded,
                  label: 'Explain legal terms',
                  onTap: () => sendMessage(
                    'What are common legal terms I should know about in contracts?',
                    null,
                    null,
                  ),
                ),
              ],
            ),
          ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFileDirectly() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt'],
      );
      if (result != null && result.files.isNotEmpty) {
        sendMessage('', result.files.first, null);
      }
    } catch (_) {}
  }


  // ── Export the current document's analysis as a shareable PDF ──────────────

  Future<void> _exportReport() async {
    if (currentDocId == null) return;

    // Blocking progress dialog — fetching insights can take a few seconds.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.accent,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Building your report…',
                style: TextStyle(color: context.textPrimary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final docName = _uploadedFileName ?? 'document';
      final bytes = await ReportService.generateBytes(
        docId: currentDocId!,
        docName: docName,
        blockchainTx: currentBlockchainTx,
      );
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      _showReportOptions(bytes, ReportService.fileName(docName));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // dismiss progress
      _showInfoSnackbar('Could not generate report: $e');
    }
  }

  /// Bottom sheet letting the user Download (save to device) or Share the report.
  void _showReportOptions(Uint8List bytes, String filename) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: 20, color: context.accentStrong),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your report is ready',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.download_rounded, color: context.accentStrong),
              title: Text('Download',
                  style: TextStyle(color: context.textPrimary)),
              subtitle: Text('Save the PDF to your device',
                  style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ReportService.download(bytes, filename);
              },
            ),
            ListTile(
              leading: Icon(Icons.ios_share_rounded, color: context.accentStrong),
              title: Text('Share',
                  style: TextStyle(color: context.textPrimary)),
              subtitle: Text('Send via apps, email, or save to Files',
                  style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
              onTap: () {
                Navigator.pop(sheetCtx);
                ReportService.share(bytes, filename);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Quick action chips after upload ────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    if (currentDocId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionChip(
              icon: Icons.summarize_rounded,
              label: 'Summarize',
              onTap: () => sendMessage('Summarize this document', null, null),
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              icon: Icons.find_in_page_rounded,
              label: 'Detect Clauses',
              onTap: () => sendMessage('Detect clauses', null, null),
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Get Insights',
              onTap: () => sendMessage('Give me insights', null, null),
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              icon: Icons.warning_amber_rounded,
              label: 'Key Risks',
              onTap: () => sendMessage('What are the key risks in this contract?', null, null),
            ),
            const SizedBox(width: 8),
            _QuickActionChip(
              icon: Icons.picture_as_pdf_rounded,
              label: 'Export PDF',
              onTap: _exportReport,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? context.bgColor : Colors.white,
      appBar: _buildAppBar(context),
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        backgroundColor: context.bgColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: const DashboardScreen(asDrawer: true),
      ),
      endDrawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.85,
        backgroundColor: context.bgColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: const SettingsScreen(asDrawer: true),
      ),
      body: Stack(
        children: [
          // Ambient glow — top left
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B5EA7).withValues(alpha: context.isDark ? 0.15 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ambient glow — bottom right
          Positioned(
            bottom: 60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.accent.withValues(alpha: context.isDark ? 0.10 : 0.11),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Quick action chips
              _buildQuickActions(context),

              Expanded(
                child: messages.isEmpty && !isTyping
                    ? _buildWelcomeHero(context)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                        itemCount: messages.length + (isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Typing bubble
                          if (isTyping && index == messages.length) {
                            return ChatBubble(
                              isUser: false,
                              label: 'AI',
                              message: '',
                              time: '',
                              isTyping: true,
                            );
                          }

                          final msg = messages[index];

                          final bubble = ChatBubble(
                            isUser: msg['sender'] == 'user',
                            label: msg['sender'] == 'user'
                                ? currentUserName[0].toUpperCase()
                                : 'AI',
                            message: msg['text'],
                            fileName: msg['fileName'],
                            fileSize: msg['fileSize'],
                            time: msg['time'],
                            delivered: msg['sender'] == 'user',
                            onCopy: () {
                              if (msg['text'] != null) {
                                Clipboard.setData(
                                    ClipboardData(text: msg['text']));
                                _showSuccessSnackbar('Message copied!');
                              }
                            },
                            onEdit: msg['sender'] == 'user'
                                ? () => _showEditDialog(index)
                                : null,
                            onDislike: msg['sender'] == 'ai'
                                ? () => _showInfoSnackbar(
                                    'Thanks for your feedback!')
                                : null,
                            onShare: msg['sender'] == 'ai'
                                ? () =>
                                    _showInfoSnackbar('Share coming soon.')
                                : null,
                          );

                          if (msg['showVerify'] == true && msg['docId'] != null) {
                            final msgDocId = msg['docId'] as String;
                            final msgTx = msg['blockchainTx'] as String?;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bubble,
                                Padding(
                                  padding: const EdgeInsets.only(left: 14, bottom: 12),
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlockchainVerifyScreen(
                                            docId: msgDocId,
                                            fileHash: msgDocId,
                                            blockchainTx: msgTx,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(Icons.verified_outlined, size: 16, color: context.accent),
                                    label: Text(
                                      'Verify on Blockchain',
                                      style: TextStyle(
                                        color: context.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: context.accent.withAlpha(60)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          return bubble;
                        },
                      ),
              ),
              MessageInputBar(onSend: sendMessage),
            ],
          ),

          // Scroll-to-bottom FAB
          if (_showScrollFab)
            Positioned(
              bottom: 90,
              right: 16,
              child: GestureDetector(
                onTap: _scrollToBottom,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.accent.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: context.softShadow,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.accent.withValues(alpha: 0.8),
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: context.appBarColor,
            border: Border(
              bottom: BorderSide(
                color: context.borderColor,
                width: 1,
              ),
            ),
          ),
        ),
        // Hamburger → opens left drawer (Dashboard)
        leading: Builder(
          builder: (ctx) => HoverIcon(
            icon: Icons.menu_rounded,
            tooltip: 'Dashboard',
            onTap: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const ScribeLogo(height: 36),
        actions: [
          // Settings gear → opens right drawer (Settings)
          Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: HoverIcon(
                icon: Icons.settings_outlined,
                tooltip: 'Settings',
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SUGGESTION CHIP (welcome screen) ─────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: context.isDark
              ? const Color(0xFF12122A)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.isDark
                ? context.accent.withValues(alpha: 0.18)
                : context.accent.withValues(alpha: 0.22),
            width: 1,
          ),
          boxShadow: context.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: context.isDark
                  ? context.accent.withValues(alpha: 0.8)
                  : context.accentStrong,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: context.isDark
                    ? context.textSecondary
                    : const Color(0xFF4A4540),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QUICK ACTION CHIP (after document upload) ────────────────────────────────

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: context.isDark
                ? [
                    context.accent.withValues(alpha: 0.14),
                    context.accentSecondary.withValues(alpha: 0.06),
                  ]
                : [
                    context.accent.withValues(alpha: 0.10),
                    context.accentSecondary.withValues(alpha: 0.05),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.accent.withValues(alpha: context.isDark ? 0.30 : 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: context.isDark
                  ? context.accent
                  : context.accentStrong,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.isDark
                    ? context.accent
                    : context.accentStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
