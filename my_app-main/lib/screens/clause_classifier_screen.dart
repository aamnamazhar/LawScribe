import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme_provider.dart';
import '../components/scribe_logo.dart';

class ClauseClassifierScreen extends StatefulWidget {
  /// Optional clause text to pre-fill (e.g. when opened from another screen).
  final String? initialText;

  const ClauseClassifierScreen({super.key, this.initialText});

  @override
  State<ClauseClassifierScreen> createState() => _ClauseClassifierScreenState();
}

class _ClauseClassifierScreenState extends State<ClauseClassifierScreen> {
  late final TextEditingController _textController;

  bool _loading = false;
  List<dynamic>? _results;
  String? _error;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
    if ((widget.initialText ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _classify());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _classify() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = 'Please paste a clause to classify.';
        _results = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = null;
    });

    try {
      final res = await ApiService.classifyProvision(text);
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Classification failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: context.appBarColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const ScribeLogo(height: 36),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.accent, context.accentSecondary],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Clause Classifier',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a single clause or provision and the AI will identify its standard legal category.',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withAlpha(20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4A90D9).withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    color: Color(0xFF4A90D9),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Trained on the LEDGAR benchmark, the classifier recognizes 100 common contract provision types. For best results, paste one clause at a time.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Clause input
            Text(
              'Clause text',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 6,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
              decoration: _inputDecoration(
                context,
                'e.g. "This Agreement shall be governed by the laws of the State of New York."',
              ),
            ),
            const SizedBox(height: 24),

            // Classify button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _classify,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _loading
                        ? const LinearGradient(
                            colors: [Color(0xFF3A3A3A), Color(0xFF3A3A3A)],
                          )
                        : LinearGradient(
                            colors: [
                              context.accent,
                              context.accentSecondary,
                              context.accent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_outlined,
                                color: Color(0xFF0A0A14),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Classify Clause',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A0A14),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_results != null) _buildResults(_results!),
            if (_error != null) _buildErrorCard(_error!),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(List<dynamic> results) {
    if (results.isEmpty) {
      return _buildErrorCard('No category could be determined for this text.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Predicted categories',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...results.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value as Map<String, dynamic>;
          final category = (r['category'] ?? '').toString();
          final conf = (r['confidence'] is num)
              ? (r['confidence'] as num).toDouble()
              : 0.0;
          return _categoryCard(category, conf, isTop: i == 0);
        }),
      ],
    );
  }

  Widget _categoryCard(String category, double confidence, {required bool isTop}) {
    final color = isTop ? context.accent : context.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop ? context.accent.withAlpha(90) : context.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isTop) ...[
                Icon(Icons.star_rounded, size: 18, color: context.accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (confidence / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: context.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B6B).withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF6B6B),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(fontSize: 13, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textHint, fontSize: 14),
      filled: true,
      fillColor: context.cardColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.accent, width: 1.4),
      ),
    );
  }
}