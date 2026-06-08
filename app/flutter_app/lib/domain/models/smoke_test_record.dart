// smoke_test_record.dart — 실기기 smoke test 기록 모델

enum SmokeTestStatus { pending, passed, failed, skipped }

class SmokeTestRecord {
  final String id;
  final String platform;
  final String checklistName;
  final SmokeTestStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SmokeTestRecord({
    required this.id,
    required this.platform,
    required this.checklistName,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// Windows smoke checklist 기본 항목.
const List<String> kDefaultWindowsSmokeChecklist = [
  '앱 실행',
  'Workspace 선택',
  'Dashboard 표시',
  'Search 기본 동작',
  'Document Archive 열기',
  'Personal Archive 열기',
  'Work Queue 열기',
  'Dry-run preview 표시',
  'approved ticket 실행 흐름',
  'Privacy 화면 표시',
  'Settings / RC 화면 표시',
  'Ollama 미실행 상태 offline 표시',
  '고대비 / 다크모드 가독성',
  '주요 버튼 50px 이상',
  'MCP sidecar 자동 시작 옵션',
  '트레이 상주 / 창 닫기 동작',
  'Windows 시작 시 자동 실행 옵션',
];

/// macOS smoke checklist 기본 항목.
const List<String> kDefaultMacOsSmokeChecklist = [
  '앱 실행',
  'Workspace 선택',
  'Dashboard 표시',
  'Search 기본 동작',
  'Document Archive 열기',
  'Personal Archive 열기',
  'Work Queue 열기',
  'Dry-run preview 표시',
  'approved ticket 실행 흐름',
  'Privacy 화면 표시',
  'LLM self-info preview/export',
  'Ollama 미실행 상태 offline 표시',
  '고대비 / 다크모드 가독성',
  '주요 버튼 50px 이상',
];
