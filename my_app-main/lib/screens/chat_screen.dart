import 'dart:convert';
import 'package:my_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import '../components/chat_bubble.dart';
import '../components/message_input.dart';
import '../components/scribe_logo.dart';
// import '../components/appbar_hover_icon.dart';
import '../components/hover_icon.dart';
import '../components/_header_button.dart';
import '../theme_provider.dart';

// ── Layman-friendly clause metadata ─────────────────────────────────────────
//
// For each of the 41 CUAD clause types the model can detect, we store:
//   - a plain-English name (no legal jargon)
//   - a one-line explanation a non-lawyer can understand
//   - a risk level (low/medium/high) used to render a 🟢/🟡/🔴 dot
//   - a category used to group clauses into sections in the chat response
//
// Edit these freely — they only affect how clauses are displayed, not how
// they're detected.
class _ClauseInfo {
  final String plainName;
  final String layExplanation;
  final String category; // key | money | risk | restrict | exit | legal
  final String risk;     // low | medium | high
  const _ClauseInfo(this.plainName, this.layExplanation, this.category, this.risk);
}

const Map<String, _ClauseInfo> _clauseInfo = {
  // ── Key details ──────────────────────────────────────────────────────────
  'Document Name':   _ClauseInfo('Type of contract',  'Tells you what kind of agreement this actually is.', 'key', 'low'),
  'Parties':         _ClauseInfo("Who's involved",    'The names of everyone signing this contract.', 'key', 'low'),
  'Agreement Date':  _ClauseInfo('Date signed',       'The day this contract was put together.', 'key', 'low'),
  'Effective Date':  _ClauseInfo('Start date',        'When the contract actually kicks in.', 'key', 'low'),
  'Expiration Date': _ClauseInfo('End date',          'When the contract is set to end.', 'key', 'low'),
  'Renewal Term':    _ClauseInfo('Auto-renewal',      'Whether the contract automatically renews itself.', 'key', 'medium'),

  // ── Money & obligations ──────────────────────────────────────────────────
  'License Grant':           _ClauseInfo('What you can use',         'The specific rights you are being given (e.g. to use software or IP).', 'money', 'low'),
  'Revenue/Profit Sharing':  _ClauseInfo('Profit split',             'How money or profits get divided between the parties.', 'money', 'medium'),
  'Minimum Commitment':      _ClauseInfo('Minimum you must spend',   'A guaranteed minimum amount you have to pay or buy.', 'money', 'medium'),
  'Volume Restriction':      _ClauseInfo('Volume limits',            'Caps on how much you can buy, sell or use.', 'money', 'medium'),
  'Price Restrictions':      _ClauseInfo('Pricing rules',            'Limits on what you can charge or how prices can change.', 'money', 'medium'),
  'Most Favored Nation':     _ClauseInfo('Best-deal guarantee',      'Promise that you get the best terms anyone else gets.', 'money', 'medium'),
  'Unlimited/All-You-Can-Eat-License': _ClauseInfo('Unlimited use',  'Use as much as you want with no caps.', 'money', 'low'),

  // ── Risk & liability ─────────────────────────────────────────────────────
  'Cap On Liability':    _ClauseInfo('Damages limit',         'Maximum amount you could be sued for if something goes wrong.', 'risk', 'medium'),
  'Uncapped Liability':  _ClauseInfo('UNLIMITED liability',   'No limit on how much you could owe — read this carefully.', 'risk', 'high'),
  'Liquidated Damages':  _ClauseInfo('Pre-set penalties',     'Specific dollar amounts you owe if you break the contract.', 'risk', 'high'),
  'Insurance':           _ClauseInfo('Insurance required',    'Type and amount of insurance you must carry.', 'risk', 'medium'),
  'Warranty Duration':   _ClauseInfo('Warranty length',       'How long the product or service is guaranteed for.', 'risk', 'low'),
  'Covenant Not To Sue': _ClauseInfo("Can't sue",             'You agree not to take legal action over certain things.', 'risk', 'high'),

  // ── Restrictions ─────────────────────────────────────────────────────────
  'Anti-Assignment':                  _ClauseInfo("Can't transfer",          "You may not give your contract rights to someone else.", 'restrict', 'medium'),
  'Non-Compete':                      _ClauseInfo("Can't compete",           "You can't work for competitors or start a similar business.", 'restrict', 'high'),
  'Exclusivity':                      _ClauseInfo('Exclusive deal',          'You must work only with this party — no competitors allowed.', 'restrict', 'high'),
  'Non-Disparagement':                _ClauseInfo('No bad-mouthing',         "You can't publicly criticize the other party.", 'restrict', 'medium'),
  'No-Solicit Of Customers':          _ClauseInfo("Can't poach customers",   "You can't try to take their customers after the deal ends.", 'restrict', 'medium'),
  'No-Solicit Of Employees':          _ClauseInfo("Can't poach staff",       "You can't try to hire away their employees.", 'restrict', 'medium'),
  'Non-Transferable License':         _ClauseInfo('License is yours alone',  "You can't share or transfer the rights you got.", 'restrict', 'medium'),
  'Competitive Restriction Exception':_ClauseInfo('Compete-ban exception',   'A specific carve-out from the non-compete rule.', 'restrict', 'low'),

  // ── Ending the contract ──────────────────────────────────────────────────
  'Termination For Convenience':       _ClauseInfo('Easy exit option',     'Either side can end the contract for any reason with notice.', 'exit', 'medium'),
  'Notice Period To Terminate Renewal':_ClauseInfo('Cancellation notice',  'How early you must tell them you want out before auto-renewal.', 'exit', 'medium'),
  'Post-Termination Services':         _ClauseInfo('After-end obligations','What you still have to do after the contract ends.', 'exit', 'medium'),

  // ── Legal & governance ───────────────────────────────────────────────────
  'Governing Law':                  _ClauseInfo('Which laws apply',         'The state or country whose laws govern any disputes.', 'legal', 'medium'),
  'Audit Rights':                   _ClauseInfo('Right to inspect records', 'They can check your books or records for compliance.', 'legal', 'medium'),
  'Change Of Control':              _ClauseInfo('What happens if sold',     'What happens to the contract if your company is acquired.', 'legal', 'medium'),
  'Third Party Beneficiary':        _ClauseInfo('Outside parties involved', 'Someone not signing has rights under this contract.', 'legal', 'medium'),
  'Joint Ip Ownership':             _ClauseInfo('Shared IP ownership',      'Both parties co-own intellectual property created together.', 'legal', 'medium'),
  'Ip Ownership Assignment':        _ClauseInfo('IP ownership transfer',    'Who ends up owning the intellectual property.', 'legal', 'high'),
  'Source Code Escrow':             _ClauseInfo('Code held by 3rd party',   'Source code is kept by an escrow agent in case of issues.', 'legal', 'low'),
  'Affiliate License-Licensee':     _ClauseInfo('Affiliate use',            "Whether the licensee's affiliates can use the rights too.", 'legal', 'low'),
  'Affiliate License-Licensor':     _ClauseInfo('Affiliate scope',          "Whether the licensor's affiliates are part of the deal.", 'legal', 'low'),
  'Irrevocable Or Perpetual License':_ClauseInfo('Forever license',         "License that can't be taken back, ever.", 'legal', 'low'),
  'Rofr/Rofo/Rofn':                 _ClauseInfo('First-right options',      'Right to be offered something first before anyone else.', 'legal', 'medium'),
};

const Map<String, String> _categoryHeaders = {
  'key':      '📋 KEY DETAILS',
  'money':    "💼 WHAT YOU'RE GETTING / PAYING",
  'risk':     '⚠️ RISK & LIABILITY',
  'restrict': '🚫 RESTRICTIONS ON YOU',
  'exit':     '🚪 ENDING THE CONTRACT',
  'legal':    '⚖️ LEGAL & GOVERNANCE',
  'other':    '📌 OTHER',
};

const List<String> _categoryOrder = [
  'key', 'money', 'risk', 'restrict', 'exit', 'legal', 'other',
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final String currentUserName = 'user';
  final ScrollController _scrollController = ScrollController();
  bool isTyping = false;
  String? currentDocumentPath;
  String? currentDocId;

  final List<Map<String, dynamic>> messages = [
    {
      'sender': 'ai',
      'type': 'text',
      'text':
          'Hello! I\'m LawScribe AI ⚖️. Upload a legal document or ask me anything about contracts, clauses, or legal terms.',
      'time': '10:00 AM',
    },
  ];

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

    if (file != null && file.path != null) {
      try {
        final response = await ApiService.uploadDocument(file.path!);
        final responseBody = await response.stream.bytesToString();

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(responseBody);
          currentDocumentPath = data["file"]["path"];
          currentDocId = data["file"]["hash"];

          setState(() {
            isTyping = false;
            messages.add({
              'sender': 'ai',
              'type': 'text',
              'text':
                  'Document uploaded successfully.\n'
                  'How can I help you with it?\n'
                  'Try: summarize, detect clauses, or ask any question about the document.',
              'time': _formatTime(DateTime.now()),
            });
          });
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
    } else {
      _simulateAIReply();
    }
  }

  Future<void> _handleDocumentQuery(String userText) async {
    setState(() => isTyping = true);
    _scrollToBottom();

    try {
      String aiResponse;
      final lowerText = userText.toLowerCase();

      if (lowerText.contains("summary") ||
          lowerText.contains("summarize") ||
          lowerText.contains("summarise")) {
        aiResponse = await ApiService.getSummary(currentDocId!);
      } else if (lowerText.contains("clause") ||
          lowerText.contains("clauses") ||
          lowerText.contains("detect")) {
        final clauses = await ApiService.getClauses(currentDocId!);
        aiResponse = _formatClausesResponse(clauses);
      } else if (lowerText.contains("insight") ||
          lowerText.contains("explain clauses") ||
          lowerText.contains("what do the clauses mean")) {
        final insights = await ApiService.getInsights(currentDocId!);
        if (insights.isEmpty) {
          aiResponse = "No clause insights available for this document.";
        } else {
          final lines = insights.map((i) =>
              "📌 ${i['clause_type']}\n${i['insight']}").join("\n\n");
          aiResponse = lines;
        }
      } else {
        // General Q&A via RAG
        aiResponse = await ApiService.queryDocument(currentDocId!, userText);
      }

      if (!mounted) return;

      setState(() {
        isTyping = false;
        messages.add({
          'sender': 'ai',
          'type': 'text',
          'text': aiResponse,
          'time': _formatTime(DateTime.now()),
        });
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isTyping = false;
        messages.add({
          'sender': 'ai',
          'type': 'text',
          'text': 'Error getting response: $e',
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

    // Bucket clauses by category, preserving the model's confidence ordering
    // within each bucket.
    final Map<String, List<Map<String, dynamic>>> grouped = {
      for (final cat in _categoryOrder) cat: [],
    };

    for (final c in clauses) {
      final type = c['clause_type'] as String;
      final info = _clauseInfo[type];
      final cat = info?.category ?? 'other';
      grouped[cat]!.add({
        'type': type,
        'confidence': c['confidence'],
        'info': info,
      });
    }

    final buffer = StringBuffer();
    final count = clauses.length;
    buffer.writeln(
      "I found $count important thing${count == 1 ? '' : 's'} in your contract.\n",
    );

    for (final cat in _categoryOrder) {
      final items = grouped[cat]!;
      if (items.isEmpty) continue;
      buffer.writeln(_categoryHeaders[cat]);
      for (final item in items) {
        final info = item['info'] as _ClauseInfo?;
        final risk = info?.risk ?? 'medium';
        final dot = risk == 'high'
            ? '🔴'
            : risk == 'medium'
                ? '🟡'
                : '🟢';
        final name = info?.plainName ?? item['type'] as String;
        final desc = info?.layExplanation ?? '';
        buffer.writeln('$dot $name');
        if (desc.isNotEmpty) {
          buffer.writeln('   $desc');
        }
      }
      buffer.writeln();
    }

    buffer.write(
      '💡 Want to know what these actually SAY in your contract? '
      'Type "give me insights" and I\'ll pull the exact wording for each one.',
    );

    return buffer.toString();
  }

  void _simulateAIReply() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final replies = [
      "Based on general legal principles, contracts must clearly define the obligations of all parties involved.",
      "From a legal standpoint, enforceability depends on mutual consent, valid consideration, and a lawful purpose.",
      "This situation may involve contractual interpretation. I recommend reviewing the termination and liability clauses carefully.",
      "In most jurisdictions, written agreements carry significantly more weight than verbal assurances.",
      "It would be advisable to review this document carefully. Would you like me to identify the key clauses?",
      "Let me break this down simply: the wording of the contract determines your rights and responsibilities.",
    ];

    setState(() {
      isTyping = false;
      messages.add({
        'sender': 'ai',
        'type': 'text',
        'text': replies[DateTime.now().millisecondsSinceEpoch % replies.length],
        'time': _formatTime(DateTime.now()),
      });
    });

    _scrollToBottom();
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
            color: const Color(0xFF6BCB77).withOpacity(0.3),
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
              color: const Color(0xFFD4AF6A),
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
            color: const Color(0xFFD4AF6A).withOpacity(0.25),
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
                  fillColor: context.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
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
                    borderSide: const BorderSide(
                      color: Color(0xFFD4AF6A),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF6A), Color(0xFFF5D98B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF6A).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Ambient glow — top left
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7B5EA7).withOpacity(0.15),
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
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFC9A84C).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
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

                    return ChatBubble(
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
                          Clipboard.setData(ClipboardData(text: msg['text']));
                          _showSuccessSnackbar('Message copied!');
                        }
                      },
                      onEdit: msg['sender'] == 'user'
                          ? () => _showEditDialog(index)
                          : null,
                      onDislike: msg['sender'] == 'ai'
                          ? () => _showInfoSnackbar('Thanks for your feedback!')
                          : null,
                      onShare: msg['sender'] == 'ai'
                          ? () => _showInfoSnackbar('Share coming soon.')
                          : null,
                    );
                  },
                ),
              ),
              MessageInputBar(onSend: sendMessage),
            ],
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
        centerTitle: false,
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7B5EA7).withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        leading: HoverIcon(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.of(context).pop(),
        ),
        title: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: ScribeLogo(height: 36),
        ),
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (screenWidth < 520) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _HoverMenuButton(
                    icon: Icons.menu_rounded,
                    items: [
                      _HoverMenuItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        onTap: () => Navigator.pushNamed(context, '/dashboard'),
                      ),
                      _HoverMenuItem(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
                );
              }
              return Row(
                children: [
                  HeaderButton(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () => Navigator.pushNamed(context, '/dashboard'),
                  ),
                  HeaderButton(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => Navigator.pushNamed(context, '/settings'),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── HOVER MENU ────────────────────────────────────────────────────────────────

class _HoverMenuButton extends StatefulWidget {
  final IconData icon;
  final List<_HoverMenuItem> items;

  const _HoverMenuButton({required this.icon, required this.items, Key? key})
    : super(key: key);

  @override
  State<_HoverMenuButton> createState() => _HoverMenuButtonState();
}

class _HoverMenuButtonState extends State<_HoverMenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: PopupMenuButton<int>(
        icon: Icon(
          widget.icon,
          color: _hover ? context.textPrimary : context.textSecondary,
        ),
        color: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        itemBuilder: (context) => List.generate(widget.items.length, (i) {
          final item = widget.items[i];
          return PopupMenuItem(
            value: i,
            child: _HoverMenuTile(
              icon: item.icon,
              label: item.label,
              onTap: () {
                Navigator.pop(context);
                item.onTap();
              },
            ),
          );
        }),
      ),
    );
  }
}

class _HoverMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _HoverMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _HoverMenuTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HoverMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_HoverMenuTile> createState() => _HoverMenuTileState();
}

class _HoverMenuTileState extends State<_HoverMenuTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0xFFD4AF6A).withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: const Color(0xFFD4AF6A).withOpacity(0.85),
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
