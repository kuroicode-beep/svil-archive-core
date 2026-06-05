// DatabaseService: SQLite DB 초기화, 마이그레이션, 연결 관리 인터페이스
// WAL 모드 설정 및 스키마 버전 관리 책임

abstract class DatabaseService {
  /// DB 초기화 (WAL 모드 활성화, 스키마 마이그레이션 포함)
  Future<void> initialize(String dbPath);

  /// DB 닫기
  Future<void> close();

  /// 현재 스키마 버전 조회
  Future<int> getSchemaVersion();

  /// 마이그레이션 실행 (version → targetVersion)
  Future<void> migrate(int targetVersion);

  /// DB 전체 재생성 (Markdown 재스캔 시 호출)
  Future<void> reset();

  /// 백업용 snapshot 생성
  Future<String> createSnapshot(String destinationPath);

  /// DB 연결 상태 확인
  Future<bool> isOpen();
}
