// Workspace: 사용자가 열어둔 문서 루트 폴더를 표현하는 도메인 모델

class Workspace {
  final String id;
  final String name;
  final String rootPath; // OS 절대경로 (플랫폼 어댑터를 통해 해석)
  final DateTime createdAt;
  final DateTime lastOpenedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.createdAt,
    required this.lastOpenedAt,
  });

  Workspace copyWith({
    String? name,
    DateTime? lastOpenedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      rootPath: rootPath,
      createdAt: createdAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }
}
