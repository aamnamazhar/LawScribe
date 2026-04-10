import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  // Backend URL. Override at run time with:
  //   flutter run --dart-define=BACKEND_URL=https://your-tunnel.trycloudflare.com
  // The default 10.0.2.2 is the special alias the Android emulator uses to
  // reach "localhost" on the host machine — works for emulator dev only.
  static const String baseUrl = String.fromEnvironment(
    "BACKEND_URL",
    defaultValue: "http://10.0.2.2:8000",
  );

  // ── Auth header ───────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {"Content-Type": "application/json"};
    final token = await user.getIdToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  static Future<http.StreamedResponse> uploadDocument(String filePath) async {
    final uri = Uri.parse("$baseUrl/documents/upload");
    final request = http.MultipartRequest("POST", uri);
    request.files.add(await http.MultipartFile.fromPath("file", filePath));

    // Attach Firebase auth token so backend can write to user's Firestore paths
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      request.headers['Authorization'] = 'Bearer $token';
    }

    return await request.send();
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  static Future<String> getSummary(String docId) async {
    final uri = Uri.parse(
      "$baseUrl/ai/summary?doc_id=${Uri.encodeComponent(docId)}",
    );
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["summary"];
    }
    throw Exception("Summary failed: ${response.body}");
  }

  // ── Q&A ───────────────────────────────────────────────────────────────────

  static Future<String> queryDocument(String docId, String question) async {
    final uri = Uri.parse("$baseUrl/ai/query");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId, "question": question}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["answer"];
    }
    throw Exception("Query failed: ${response.body}");
  }

  // ── Clause Detection ──────────────────────────────────────────────────────

  static Future<List<dynamic>> getClauses(String docId) async {
    final uri = Uri.parse("$baseUrl/ai/clauses");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["clauses"];
    }
    throw Exception("Clause detection failed: ${response.body}");
  }

  // ── Insights ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getInsights(String docId) async {
    final uri = Uri.parse("$baseUrl/ai/insights");
    final headers = await _authHeaders();
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({"doc_id": docId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["insights"];
    }
    throw Exception("Insights failed: ${response.body}");
  }

  // ── Blockchain Verify ─────────────────────────────────────────────────────

  static Future<bool> verifyDocument(String docId, String fileHash) async {
    final uri = Uri.parse(
      "$baseUrl/ai/verify?doc_id=${Uri.encodeComponent(docId)}&file_hash=${Uri.encodeComponent(fileHash)}",
    );
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["verified"] as bool;
    }
    throw Exception("Verify failed: ${response.body}");
  }
}
