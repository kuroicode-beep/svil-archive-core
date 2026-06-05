---
title: "SAC Service Contract"
author: "Claude Code (Sonnet)"
project: "SAC"
type: "서비스 계약"
status: "draft"
created: "2026-06-05"
---

# SAC Service Contract — Phase 1 Skeleton

UI와 MCP sidecar가 공유하는 서비스 경계 정의.

---

## 공유 서비스 경계 원칙

```
Flutter UI ──┐
             ├──→ ArchiveService (인터페이스)
MCP Sidecar ─┘         ↓
                   구현체 (data/db, data/file)
```

UI와 MCP 모두 ArchiveService 인터페이스를 통해서만 문서에 접근한다.

---

## WorkspaceService

```dart
Future<List<Workspace>> listWorkspaces()
Future<Workspace> createWorkspace({name, rootPath})
Future<Workspace> openWorkspace(String workspaceId)
Future<Workspace?> getActiveWorkspace()
Future<void> removeWorkspace(String workspaceId)
```

---

## ArchiveService

```dart
Future<List<DocumentMetadata>> listDocuments()
Future<DocumentMetadata?> getDocument(String id)
Future<Document?> getDocumentWithContent(String id)
Future<Document> createDocument(CreateDocumentInput input)
Future<Document> updateDocument(UpdateDocumentInput input)
  // ↑ baseRevision 불일치 시 ConflictException 발생 — AI 덮어쓰기 방지
Future<void> moveDocumentToTrash(String id)
Future<Document> restoreDocument(String trashItemId)
Future<DocumentMetadata> moveDocument(String id, String newRelativePath)
```

### AI 덮어쓰기 방지 정책

`updateDocument(input)` 호출 시:
1. `input.baseRevision` vs DB `currentRevision` 비교
2. 불일치 시 → `ConflictException` throw
3. AI는 새 문서 생성 또는 사용자 승인 후 merge만 가능

---

## SearchService

```dart
Future<List<SearchResult>> search(SearchQuery query)   // FTS5 Phase 1
Future<List<SearchResult>> searchSimilar(String documentId, {int limit})  // 벡터 Phase 3
```

---

## SyncService

```dart
Future<void> fullRescan(String workspaceId)
Future<void> onFileChanged(String relativePath)
Future<SyncState> getSyncState(String documentId)
Future<bool> validateAiRevision(String documentId, int baseRevision)
Future<void> appendJournal({documentId, actor, action, note})
  // Phase 1: 기록만 수행, 복구 엔진 없음
```

---

## SettingsService / ThemeService / TtsService

```dart
// SettingsService
Future<AppSettings> getSettings()
Future<void> saveSettings(AppSettings settings)

// ThemeService
Future<ThemeSettings> getThemeSettings()
Future<void> applyTheme(AppTheme theme)
Future<void> toggleHighContrast(bool enabled)   // footer 즉시 적용

// TtsService
Future<void> speakDocument(String documentId)
Future<void> speakSection(String documentId, String headingPath)
Future<void> pause() / resume() / stop()
Future<void> setSpeed(double multiplier)        // 0.5 ~ 2.0
```

---

## DocumentRepository (DB 계층)

```dart
Future<DocumentMetadata?> findById(String id)
Future<DocumentMetadata?> findByPath(String relativePath)
Future<List<DocumentMetadata>> findAll({status, project, type})
Future<void> save(DocumentMetadata metadata)
Future<void> delete(String id)
Future<bool> exists(String id)
```

---

## DocumentFileStore (파일 계층)

```dart
Future<String> readContent(String relativePath)
Future<void> writeContent(String relativePath, String markdownWithFrontmatter)
Future<bool> exists(String relativePath)
Future<void> move(String fromPath, String toPath)
Future<void> delete(String relativePath)
Future<String> computeHash(String relativePath)
Future<List<String>> listMarkdownFiles(String relativeDirPath)
Future<DocumentMetadata> parseFrontmatter(String relativePath)
```

---

## DatabaseService

```dart
Future<void> initialize(String dbPath)   // WAL 모드 활성화 + 마이그레이션
Future<void> close()
Future<int> getSchemaVersion()
Future<void> migrate(int targetVersion)
Future<void> reset()                     // Markdown 재스캔 시 DB 재생성
Future<String> createSnapshot(String destinationPath)
Future<bool> isOpen()
```

---

## TrashService

```dart
Future<TrashItem> moveToTrash(String documentId, {String? actor})
Future<void> restoreFromTrash(String trashItemId, {String? targetPath})
Future<List<TrashItem>> listTrashItems()
Future<void> permanentlyDelete(String trashItemId)
Future<void> emptyTrash()
```

---

## DesignAssetRegistry

```dart
Future<void> register(DesignAssetEntry entry)
Future<List<DesignAssetEntry>> listByTool(String tool)
Future<List<DesignAssetEntry>> listAll()
Future<void> unregister(String relativePath)
```

---

## McpBridgeService

```dart
Future<void> startSidecar() / stopSidecar()
Future<bool> isSidecarRunning()
Future<List<McpToolDefinition>> listTools()
Future<void> setToolEnabled(String toolName, bool enabled)
Future<List<WorkTicket>> listTickets()
Future<void> cancelTicket(String ticketId)
Future<PermissionToken> issueToken({type, agentId, documentId, validity})
Future<void> revokeToken(String tokenId)
```

---

*Updated: 2026-06-05*
