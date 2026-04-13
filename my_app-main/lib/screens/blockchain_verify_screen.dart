import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme_provider.dart';
import '../components/scribe_logo.dart';

class BlockchainVerifyScreen extends StatefulWidget {
  final String? docId;
  final String? fileHash;
  final String? blockchainTx;

  const BlockchainVerifyScreen({
    super.key,
    this.docId,
    this.fileHash,
    this.blockchainTx,
  });

  @override
  State<BlockchainVerifyScreen> createState() => _BlockchainVerifyScreenState();
}

class _BlockchainVerifyScreenState extends State<BlockchainVerifyScreen> {
  late final TextEditingController _docIdController;
  late final TextEditingController _hashController;

  bool _loading = false;
  bool? _verified;
  String? _error;

  @override
  void initState() {
    super.initState();
    _docIdController = TextEditingController(text: widget.docId ?? '');
    _hashController = TextEditingController(text: widget.fileHash ?? '');

    // Auto-verify if both values were passed in
    if (widget.docId != null && widget.fileHash != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void dispose() {
    _docIdController.dispose();
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final docId = _docIdController.text.trim();
    final hash = _hashController.text.trim();

    if (docId.isEmpty || hash.isEmpty) {
      setState(() {
        _error = 'Please enter both Document ID and File Hash.';
        _verified = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _verified = null;
    });

    try {
      final result = await ApiService.verifyDocument(docId, hash);
      if (!mounted) return;
      setState(() {
        _verified = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Verification failed: $e';
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF6A), Color(0xFFF5D98B)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Blockchain Verification',
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
              'Verify the integrity of a document by checking its hash against the blockchain record.',
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF4A90D9).withAlpha(40),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF4A90D9),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Document hashes are recorded immutably on the Ethereum blockchain at upload time. This screen lets you verify that a document has not been altered.',
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

            // Document ID field
            Text(
              'Document ID',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _docIdController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(
                context,
                'SHA-256 hash from upload response',
              ),
            ),
            const SizedBox(height: 16),

            // File Hash field
            Text(
              'File Hash',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hashController,
              style: TextStyle(color: context.textPrimary, fontSize: 14),
              decoration: _inputDecoration(context, 'SHA-256 hash of the file'),
            ),
            const SizedBox(height: 28),

            // Verify button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _loading
                        ? const LinearGradient(
                            colors: [Color(0xFF3A3A3A), Color(0xFF3A3A3A)],
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFFD4AF6A),
                              Color(0xFFF5D98B),
                              Color(0xFFD4AF6A),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                    borderRadius: BorderRadius.circular(14),
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
                                Icons.verified_outlined,
                                color: Color(0xFF0A0A14),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Verify on Blockchain',
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

            // Blockchain Tx Hash (if available from upload)
            if (widget.blockchainTx != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Hash',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.blockchainTx!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textPrimary,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: context.textSecondary,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.blockchainTx!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transaction hash copied'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Result
            if (_verified != null) _buildResultCard(_verified!),
            if (_error != null) _buildErrorCard(_error!),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool verified) {
    final color = verified ? const Color(0xFF4CAF82) : const Color(0xFFFF6B6B);
    final icon = verified ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = verified ? 'Verified' : 'Not Verified';
    final subtitle = verified
        ? 'This document hash matches the blockchain record. The document has not been altered since upload.'
        : 'The hash does not match the blockchain record. The document may have been modified, or was never logged.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (verified) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: context.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Immutable record on Ethereum',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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
        borderRadius: BorderRadius.circular(14),
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
        borderSide: const BorderSide(color: Color(0xFFD4AF6A), width: 1.4),
      ),
      suffixIcon: IconButton(
        icon: Icon(
          Icons.content_paste_rounded,
          size: 18,
          color: context.textSecondary,
        ),
        onPressed: () async {
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (data?.text != null) {
            if (hint.contains('file')) {
              _hashController.text = data!.text!;
            } else {
              _docIdController.text = data!.text!;
            }
          }
        },
      ),
    );
  }
}
