import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Persists chat conversations to Firestore so they survive app restarts.
///
/// Layout (mirrors the dashboard's direct-Firestore pattern):
///   users/{uid}/chats/{chatId}                 — metadata (title, doc context)
///   users/{uid}/chats/{chatId}/messages/{id}   — individual messages
///
/// All writes are best-effort: if the user is signed out or Firestore rules
/// reject the write, methods fail quietly so the chat UI keeps working.
class ChatStore {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _chatsCol() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('chats');
  }

  /// Create a new chat document and return its id (null if not signed in).
  static Future<String?> createChat({
    String? title,
    String? docId,
    String? docName,
    String? docPath,
  }) async {
    final col = _chatsCol();
    if (col == null) return null;
    try {
      final ref = col.doc();
      await ref.set({
        'title': (title == null || title.trim().isEmpty) ? 'New chat' : title,
        'docId': docId,
        'docName': docName,
        'docPath': docPath,
        'lastMessage': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } catch (_) {
      return null;
    }
  }

  /// Append a single message to a chat.
  static Future<void> addMessage(
    String chatId,
    Map<String, dynamic> message,
  ) async {
    final col = _chatsCol();
    if (col == null) return;
    try {
      await col.doc(chatId).collection('messages').add({
        ...message,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {/* best-effort */}
  }

  /// Merge metadata onto a chat (title, lastMessage, doc context) and bump
  /// updatedAt so it sorts to the top of the recent list.
  static Future<void> updateMeta(
    String chatId,
    Map<String, dynamic> data,
  ) async {
    final col = _chatsCol();
    if (col == null) return;
    try {
      await col.doc(chatId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {/* best-effort */}
  }

  /// Load a chat's metadata document (null if missing).
  static Future<Map<String, dynamic>?> loadChatMeta(String chatId) async {
    final col = _chatsCol();
    if (col == null) return null;
    try {
      final snap = await col.doc(chatId).get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  /// Load all messages of a chat in chronological order.
  static Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    final col = _chatsCol();
    if (col == null) return [];
    try {
      final snap = await col
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt')
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Live list of recent chats for the dashboard drawer.
  static Stream<List<ChatSummary>> recentChatsStream({int limit = 20}) {
    final col = _chatsCol();
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ChatSummary.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  /// Delete a chat and all its messages.
  static Future<void> deleteChat(String chatId) async {
    final col = _chatsCol();
    if (col == null) return;
    try {
      final msgs = await col.doc(chatId).collection('messages').get();
      for (final m in msgs.docs) {
        await m.reference.delete();
      }
      await col.doc(chatId).delete();
    } catch (_) {/* best-effort */}
  }
}

/// Lightweight view of a chat for list display.
class ChatSummary {
  final String id;
  final String title;
  final String lastMessage;
  final String? docName;
  final DateTime updatedAt;

  const ChatSummary({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.docName,
    required this.updatedAt,
  });

  factory ChatSummary.fromDoc(String id, Map<String, dynamic> data) {
    final ts = data['updatedAt'];
    return ChatSummary(
      id: id,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'New chat',
      lastMessage: (data['lastMessage'] as String?) ?? '',
      docName: data['docName'] as String?,
      updatedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
