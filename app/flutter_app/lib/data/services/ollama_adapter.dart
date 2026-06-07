// ollama_adapter.dart — Ollama 로컬 AI 연결 adapter skeleton

import 'dart:convert';
import 'dart:io';

import '../../domain/models/dashboard.dart';
import '../../domain/services/local_ai_service.dart';

class OllamaAdapter implements LocalAiService {
  final String baseUrl;
  final Duration timeout;

  OllamaAdapter({
    this.baseUrl = 'http://127.0.0.1:11434',
    this.timeout = const Duration(seconds: 2),
  });

  @override
  Future<LocalAiStatus> checkStatus() async {
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 200) {
        return LocalAiStatus(
          state: LocalAiConnectionState.connected,
          label: '연결됨',
          endpoint: baseUrl,
        );
      }
      return LocalAiStatus(
        state: LocalAiConnectionState.error,
        label: '응답 오류 (${response.statusCode})',
        endpoint: baseUrl,
      );
    } on SocketException {
      return LocalAiStatus(
        state: LocalAiConnectionState.offline,
        label: '연결 안 됨',
        endpoint: baseUrl,
      );
    } on IOException {
      return LocalAiStatus(
        state: LocalAiConnectionState.offline,
        label: '연결 안 됨',
        endpoint: baseUrl,
      );
    } catch (_) {
      return LocalAiStatus(
        state: LocalAiConnectionState.offline,
        label: '연결 안 됨',
        endpoint: baseUrl,
      );
    }
  }

  @override
  Future<List<LocalAiModel>> listModels() async {
    final status = await checkStatus();
    if (status.state != LocalAiConnectionState.connected) {
      return const [];
    }
    try {
      final uri = Uri.parse('$baseUrl/api/tags');
      final client = HttpClient();
      client.connectionTimeout = timeout;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) return const [];
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return const [];
      final models = decoded['models'];
      if (models is! List) return const [];
      return models
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => LocalAiModel(
              name: m['name']?.toString() ?? 'unknown',
              family: m['details'] is Map ? (m['details'] as Map)['family']?.toString() : null,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
