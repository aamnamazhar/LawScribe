import 'package:flutter/material.dart';
import '../services/chat_store.dart';
import '../theme_provider.dart';

/// Search across the user's saved conversations (by title, last message, or
/// document name) and open one. Backed by the persisted chats in Firestore.
class ChatSearchScreen extends StatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ChatSummary> _filter(List<ChatSummary> chats) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q) ||
          (c.docName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _openChat(String chatId) {
    Navigator.of(context).pushReplacementNamed('/chat', arguments: chatId);
  }

  Future<void> _confirmDelete(ChatSummary chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.popupColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete chat?',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '"${chat.title}" and all its messages will be permanently deleted.',
          style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // The StreamBuilder rebuilds automatically once the doc is removed.
      await ChatStore.deleteChat(chat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.appBarColor,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: context.borderColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.textSecondary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: TextStyle(color: context.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search your chats…',
            hintStyle: TextStyle(color: context.textHint, fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: context.textSecondary, size: 20),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: StreamBuilder<List<ChatSummary>>(
        stream: ChatStore.recentChatsStream(limit: 100),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.textSecondary,
              ),
            );
          }
          final results = _filter(snap.data ?? []);
          if (results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _query.isEmpty
                      ? 'No conversations yet. Start a chat and it will show up here.'
                      : 'No chats match "$_query".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: 0.5,
              color: context.dividerColor,
              indent: 16,
              endIndent: 16,
            ),
            itemBuilder: (context, i) {
              final chat = results[i];
              final preview = chat.lastMessage.isNotEmpty
                  ? chat.lastMessage
                  : (chat.docName ?? 'Tap to open');
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B5EA7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    chat.docName != null
                        ? Icons.description_outlined
                        : Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: const Color(0xFF7B5EA7),
                  ),
                ),
                title: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: context.textSecondary,
                  ),
                  tooltip: 'Delete chat',
                  onPressed: () => _confirmDelete(chat),
                ),
                onTap: () => _openChat(chat.id),
              );
            },
          );
        },
      ),
    );
  }
}
