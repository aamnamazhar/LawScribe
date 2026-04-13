import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../components/scribe_logo.dart';
import '../../../components/dashboard_stat_card.dart';
import '../../../components/dashboard_quick_action.dart';
import '../../../components/_header_button.dart';
import '../theme_provider.dart';

// ── DATA MODELS ───────────────────────────────────────────────────────────────

class DashboardStats {
  final int totalDocs;
  final int totalChats;
  final int aiResponses;
  final int pending;
  final int docsThisWeek;
  final int chatsVsYesterday;

  const DashboardStats({
    this.totalDocs = 0,
    this.totalChats = 0,
    this.aiResponses = 0,
    this.pending = 0,
    this.docsThisWeek = 0,
    this.chatsVsYesterday = 0,
  });

  factory DashboardStats.fromFirestore(Map<String, dynamic> data) {
    return DashboardStats(
      totalDocs: (data['totalDocs'] ?? 0) as int,
      totalChats: (data['totalChats'] ?? 0) as int,
      aiResponses: (data['aiResponses'] ?? 0) as int,
      pending: (data['pending'] ?? 0) as int,
      docsThisWeek: (data['docsThisWeek'] ?? 0) as int,
      chatsVsYesterday: (data['chatsVsYesterday'] ?? 0) as int,
    );
  }
}

class DocumentItem {
  final String id;
  final String name;
  final String meta;
  final String status;
  final String fileType;
  final DateTime uploadedAt;

  const DocumentItem({
    required this.id,
    required this.name,
    required this.meta,
    required this.status,
    required this.fileType,
    required this.uploadedAt,
  });

  factory DocumentItem.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['uploadedAt'];
    final uploadedAt = ts != null ? (ts as Timestamp).toDate() : DateTime.now();
    final sizeKb = (data['sizeKb'] ?? 0) as int;
    final sizeLabel = sizeKb >= 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '$sizeKb KB';
    final timeAgo = _timeAgo(uploadedAt);
    return DocumentItem(
      id: id,
      name: data['name'] ?? 'Untitled',
      meta: '$timeAgo · $sizeLabel',
      status: data['status'] ?? 'Pending',
      fileType: data['fileType'] ?? 'pdf',
      uploadedAt: uploadedAt,
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} days ago';
  }
}

class ActivityItem {
  final String text;
  final String time;
  final String type; // 'ai', 'chat', 'upload', 'review'

  const ActivityItem({
    required this.text,
    required this.time,
    required this.type,
  });

  factory ActivityItem.fromFirestore(Map<String, dynamic> data) {
    final ts = data['time'];
    final time = ts != null
        ? DocumentItem._timeAgo((ts as Timestamp).toDate())
        : '';
    return ActivityItem(
      text: data['text'] ?? '',
      time: time,
      type: data['type'] ?? 'upload',
    );
  }

  Color get dotColor {
    switch (type) {
      case 'ai':
        return const Color(0xFF4CAF82);
      case 'chat':
        return const Color(0xFF4A90D9);
      case 'upload':
        return const Color(0xFF7B5EA7);
      case 'review':
        return const Color(0xFFD4AF6A);
      default:
        return const Color(0xFF7B5EA7);
    }
  }
}

// ── DASHBOARD SCREEN ──────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final bool asDrawer;
  const DashboardScreen({super.key, this.asDrawer = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;

  // ── Firestore streams ────────────────────────────────────────────────────

  Stream<DashboardStats> get _statsStream {
    final uid = _uid;
    if (uid == null) return Stream.value(const DashboardStats());
    return _db
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('summary')
        .snapshots()
        .map(
          (snap) => snap.exists
              ? DashboardStats.fromFirestore(snap.data()!)
              : const DashboardStats(),
        );
  }

  Stream<List<DocumentItem>> get _docsStream {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('documents')
        .orderBy('uploadedAt', descending: true)
        .limit(3)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DocumentItem.fromFirestore(d.id, d.data()))
              .toList(),
        );
  }

  Stream<List<ActivityItem>> get _activityStream {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(uid)
        .collection('activity')
        .orderBy('time', descending: true)
        .limit(4)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => ActivityItem.fromFirestore(d.data())).toList(),
        );
  }

  Stream<List<double>> get _weeklyUsageStream {
    final uid = _uid;
    if (uid == null) return Stream.value(List.filled(7, 0.0));
    return _db
        .collection('users')
        .doc(uid)
        .collection('weeklyUsage')
        .orderBy('day')
        .limit(7)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return List.filled(7, 0.0);
          final counts = snap.docs.map((d) => (d['count'] ?? 0) as int).toList();
          final maxVal = counts.reduce((a, b) => a > b ? a : b);
          if (maxVal == 0) return List.filled(7, 0.0);
          return counts.map((c) => c / maxVal).toList();
        });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    return Stack(
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
                  const Color(0xFF7B5EA7).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Ambient glow — bottom right
        Positioned(
          bottom: -40,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFC9A84C).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(label: 'Dashboard'),
              const SizedBox(height: 16),

              // ── Stat cards (responsive grid) ─────────────────────────
              _buildStatsGrid(),
              const SizedBox(height: 24),

              // ── Quick actions ────────────────────────────────────────
              const _SectionHeader(label: 'Quick actions'),
              const SizedBox(height: 12),
              DashboardQuickAction(
                icon: Icons.auto_awesome_rounded,
                label: 'New chat',
                subtitle: 'Start an AI conversation',
                color: const Color(0xFF7B5EA7),
                onTap: () {
                  if (widget.asDrawer) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushNamed(context, '/chat');
                  }
                },
              ),
              const SizedBox(height: 8),
              DashboardQuickAction(
                icon: Icons.upload_file_outlined,
                label: 'Upload document',
                subtitle: 'PDF, DOCX, TXT',
                color: const Color(0xFF4A90D9),
                onTap: () {
                  if (widget.asDrawer) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushNamed(context, '/chat');
                  }
                },
              ),
              const SizedBox(height: 8),
              DashboardQuickAction(
                icon: Icons.edit_note_rounded,
                label: 'New document',
                subtitle: 'Start from scratch',
                color: const Color(0xFF4CAF82),
                onTap: () {
                  if (widget.asDrawer) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushNamed(context, '/chat');
                  }
                },
              ),
              const SizedBox(height: 28),

              // ── Recent documents ─────────────────────────────────────
              const _SectionHeader(
                label: 'Recent documents',
                action: 'View all',
              ),
              const SizedBox(height: 12),
              _buildRecentDocs(),
              const SizedBox(height: 28),

              // ── Activity feed ────────────────────────────────────────
              const _SectionHeader(label: 'Recent activity', action: 'Today'),
              const SizedBox(height: 12),
              _buildActivityFeed(),
              const SizedBox(height: 28),

              // ── Usage quota ──────────────────────────────────────────
              const _SectionHeader(
                label: 'Usage this month',
                action: 'Free plan',
              ),
              const SizedBox(height: 12),
              _buildUsageQuota(),
              const SizedBox(height: 28),

              // ── Weekly bar chart ─────────────────────────────────────
              const _SectionHeader(label: 'Weekly usage'),
              const SizedBox(height: 12),
              _buildWeeklyChart(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // When used inside a Drawer, skip the Scaffold/AppBar wrapper.
    if (widget.asDrawer) {
      return Container(
        color: context.bgColor,
        child: SafeArea(child: _buildBody(context)),
      );
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  // ── Responsive stat cards ────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    return StreamBuilder<DashboardStats>(
      stream: _statsStream,
      builder: (context, snap) {
        final stats = snap.data ?? const DashboardStats();
        final cards = [
          DashboardStatCard(
            title: 'Documents',
            value: '${stats.totalDocs}',
            icon: Icons.description_outlined,
            color: const Color(0xFF7B5EA7),
            delta: stats.docsThisWeek > 0 ? '↑ ${stats.docsThisWeek}' : null,
            subtitle: 'this week',
          ),
          DashboardStatCard(
            title: 'Chats today',
            value: '${stats.totalChats}',
            icon: Icons.chat_bubble_outline_rounded,
            color: const Color(0xFF4A90D9),
            delta: stats.chatsVsYesterday > 0
                ? '↑ ${stats.chatsVsYesterday}'
                : null,
            subtitle: 'vs yesterday',
          ),
          DashboardStatCard(
            title: 'AI responses',
            value: '${stats.aiResponses}',
            icon: Icons.auto_awesome_outlined,
            color: const Color(0xFF4CAF82),
            subtitle: 'total',
          ),
          DashboardStatCard(
            title: 'Pending',
            value: '${stats.pending}',
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFFD4AF6A),
            subtitle: 'in queue',
          ),
        ];

        // Responsive: 2 cols on mobile, 4 cols on wide screens
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width > 600 ? 4 : 2;
            final aspectRatio = crossAxisCount == 4 ? 1.2 : 0.95;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspectRatio,
              children: cards,
            );
          },
        );
      },
    );
  }

  // ── Recent documents ─────────────────────────────────────────────────────

  Widget _buildRecentDocs() {
    return StreamBuilder<List<DocumentItem>>(
      stream: _docsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return _emptyCard('No documents yet. Upload one to get started.');
        }
        return _SectionCard(
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final i = entry.key;
              final doc = entry.value;
              return _DocItem(
                icon: _iconForType(doc.fileType),
                iconColor: _colorForType(doc.fileType),
                name: doc.name,
                meta: doc.meta,
                status: doc.status,
                statusColor: _colorForStatus(doc.status),
                isLast: i == docs.length - 1,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Activity feed ─────────────────────────────────────────────────────────

  Widget _buildActivityFeed() {
    return StreamBuilder<List<ActivityItem>>(
      stream: _activityStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingCard();
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return _emptyCard('No activity yet.');
        }
        return _SectionCard(
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _ActivityItem(
                dotColor: item.dotColor,
                text: item.text,
                time: item.time,
                isLast: i == items.length - 1,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Usage quota ───────────────────────────────────────────────────────────

  Widget _buildUsageQuota() {
    return StreamBuilder<DashboardStats>(
      stream: _statsStream,
      builder: (context, snap) {
        final stats = snap.data ?? const DashboardStats();
        const maxDocs = 100;
        const maxResponses = 500;
        const maxStorageGb = 10.0;

        return _SectionCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                _QuotaRow(
                  label: 'AI responses',
                  value: '${stats.aiResponses} / $maxResponses',
                  fraction: (stats.aiResponses / maxResponses).clamp(0.0, 1.0),
                  color: const Color(0xFF7B5EA7),
                ),
                const SizedBox(height: 14),
                _QuotaRow(
                  label: 'Documents',
                  value: '${stats.totalDocs} / $maxDocs',
                  fraction: (stats.totalDocs / maxDocs).clamp(0.0, 1.0),
                  color: const Color(0xFF4CAF82),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Weekly chart ──────────────────────────────────────────────────────────

  Widget _buildWeeklyChart() {
    return StreamBuilder<List<double>>(
      stream: _weeklyUsageStream,
      builder: (context, snap) {
        final values = snap.data ?? [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        return _SectionCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily chats this week',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
                const SizedBox(height: 12),
                _WeeklyBarChart(values: values),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _loadingCard() => _SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.textSecondary,
          ),
        ),
      ),
    ),
  );

  Widget _emptyCard(String message) => _SectionCard(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: context.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'docx':
      case 'doc':
        return Icons.article_outlined;
      default:
        return Icons.notes_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFD4AF6A);
      case 'docx':
      case 'doc':
        return const Color(0xFF4A90D9);
      default:
        return const Color(0xFF7B5EA7);
    }
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
        return const Color(0xFF4CAF82);
      case 'review':
      case 'pending':
        return const Color(0xFFD4AF6A);
      case 'failed':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF4A90D9);
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(72),
      child: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Builder(
          builder: (ctx) => Container(
            decoration: BoxDecoration(
              color: ctx.appBarColor,
              border: Border(
                bottom: BorderSide(color: ctx.borderColor, width: 1),
              ),
            ),
          ),
        ),
        title: const ScribeLogo(height: 36),
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
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        onTap: () => Navigator.pushNamed(context, '/chat'),
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
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Chat',
                    onTap: () => Navigator.pushNamed(context, '/chat'),
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

// ── SHARED SECTION WIDGETS ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          label,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String? action;
  const _SectionHeader({required this.label, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        if (action != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: context.borderColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 0.5),
      ),
      child: child,
    );
  }
}

// ── DOC ITEM ──────────────────────────────────────────────────────────────────

class _DocItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String name;
  final String meta;
  final String status;
  final Color statusColor;
  final bool isLast;

  const _DocItem({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.meta,
    required this.status,
    required this.statusColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.dividerColor,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

// ── ACTIVITY ITEM ─────────────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final Color dotColor;
  final String text;
  final String time;
  final bool isLast;

  const _ActivityItem({
    required this.dotColor,
    required this.text,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 0.5,
            color: context.dividerColor,
            indent: 14,
            endIndent: 14,
          ),
      ],
    );
  }
}

// ── QUOTA ROW ─────────────────────────────────────────────────────────────────

class _QuotaRow extends StatelessWidget {
  final String label;
  final String value;
  final double fraction;
  final Color color;

  const _QuotaRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.progressBg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── WEEKLY BAR CHART ──────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<double> values;
  const _WeeklyBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const activeColor = Color(0xFF7B5EA7);
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun

    final chartValues = values.length == 7 ? values : List.filled(7, 0.0);

    return SizedBox(
      height: 84,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(days.length, (i) {
          final isToday = i == todayIndex;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  height: (56 * chartValues[i]).clamp(4.0, 56.0),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isToday ? activeColor : context.progressBg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isToday
                          ? activeColor.withValues(alpha: 0.5)
                          : context.dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  days[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: isToday ? activeColor : context.textSecondary,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── HOVER MENU ────────────────────────────────────────────────────────────────

class _HoverMenuButton extends StatefulWidget {
  final IconData icon;
  final List<_HoverMenuItem> items;

  const _HoverMenuButton({required this.icon, required this.items});

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
  });

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
                ? const Color(0xFFD4AF6A).withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: const Color(0xFFD4AF6A).withValues(alpha: 0.85),
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
