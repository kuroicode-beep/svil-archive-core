// content_hasher.dart — Markdown 본문 SHA-256 해시 계산

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// UTF-8 문자열 본문의 SHA-256 해시를 hex 문자열로 반환한다.
String computeContentHash(String body) {
  final bytes = utf8.encode(body);
  return sha256.convert(bytes).toString();
}
