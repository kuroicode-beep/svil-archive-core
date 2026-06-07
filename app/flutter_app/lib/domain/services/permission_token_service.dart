// permission_token_service.dart — 권한 토큰 서비스 인터페이스

import '../models/work_queue.dart';

abstract class PermissionTokenService {
  /// 권한 토큰을 발급한다.
  Future<PermissionTokenRecord> issueToken({
    required PermissionLevel tokenType,
    required String actor,
    required String scope,
    Duration? validity,
  });

  /// 권한 토큰을 폐기한다.
  Future<void> revokeToken(String tokenId);

  /// 활성 토큰 목록을 조회한다.
  Future<List<PermissionTokenRecord>> listActiveTokens();

  /// 타입별 활성 토큰 수를 조회한다.
  Future<int> countActiveByType(PermissionLevel type);

  /// 활성 토큰이 유효한지 검증한다.
  Future<bool> validateActiveToken({
    required String tokenId,
    required PermissionLevel tokenType,
    required String actor,
    String? scope,
  });
}
