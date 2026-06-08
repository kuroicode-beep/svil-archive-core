# package_windows_rc.ps1 — Windows portable RC 패키지 생성 (MCP sidecar 포함)
param(
    [string]$Version = "0.1.0-rc.1",
    [string]$Commit = "",
    [switch]$SkipFlutterBuild,
    [switch]$UseSprint12BImplementationCommit
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$flutterApp = Join-Path $root "app\flutter_app"
$sidecarRoot = Join-Path $root "mcp\sidecar"
$binRoot = Join-Path $root "bin\windows"

function Get-SidecarNativeBindingPath {
    param([string]$SidecarRoot)
    return Join-Path $SidecarRoot "node_modules\better-sqlite3\build\Release\better_sqlite3.node"
}

function Install-SidecarDependencies {
    param(
        [string]$SidecarRoot,
        [switch]$ProductionOnly
    )
    Push-Location $SidecarRoot
    try {
        if ($ProductionOnly) {
            npm ci --omit=dev
        } else {
            npm ci
        }
        npm rebuild better-sqlite3
        $nativeBinding = Get-SidecarNativeBindingPath -SidecarRoot $SidecarRoot
        if (-not (Test-Path $nativeBinding)) {
            throw "better_sqlite3.node not found after install: $nativeBinding"
        }
        Write-Host "Sidecar native binding OK: $nativeBinding"
        return $true
    } finally {
        Pop-Location
    }
}

if (-not $Commit) {
    Push-Location $root
    if ($UseSprint12BImplementationCommit) {
        $Commit = "c2e73a4"
    } else {
        $Commit = (git rev-parse --short HEAD).Trim()
    }
    Pop-Location
}

$pkgName = "sac_v${Version}_windows_x64_${Commit}"
$dest = Join-Path $binRoot $pkgName
$releaseSrc = Join-Path $flutterApp "build\windows\x64\runner\Release"

Write-Host "==> Building MCP sidecar"
Install-SidecarDependencies -SidecarRoot $sidecarRoot | Out-Null
Push-Location $sidecarRoot
npm run build
Pop-Location

if (-not $SkipFlutterBuild) {
    Write-Host "==> Building Flutter Windows release"
    Push-Location $flutterApp
    flutter build windows --release --build-name=$Version --build-number=1
    Pop-Location
}

if (-not (Test-Path $releaseSrc)) {
    throw "Release build not found: $releaseSrc"
}

Write-Host "==> Assembling portable package at $dest"
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Copy-Item -Recurse $releaseSrc $dest

$sidecarDest = Join-Path $dest "mcp\sidecar"
New-Item -ItemType Directory -Force -Path $sidecarDest | Out-Null
Copy-Item (Join-Path $sidecarRoot "dist") (Join-Path $sidecarDest "dist") -Recurse
Copy-Item (Join-Path $sidecarRoot "package.json") $sidecarDest
Copy-Item (Join-Path $sidecarRoot "package-lock.json") $sidecarDest

Write-Host "==> Installing production node_modules in package sidecar"
$nativeBindingIncluded = Install-SidecarDependencies -SidecarRoot $sidecarDest -ProductionOnly

$sidecarReadme = @"
SAC MCP Sidecar (local stdio)
Version: $Version
Commit: $Commit

- 로컬 stdio 기반 MCP sidecar입니다.
- remote MCP 서버를 열지 않습니다.
- 외부 AI API를 호출하지 않습니다.
- 실행: node dist/index.js (Node.js 18+ 필요)
- 포터블 폴더 이동 시 mcp/sidecar 전체를 함께 유지하세요.
"@
Set-Content -Path (Join-Path $sidecarDest "MCP_SIDECAR.txt") -Value $sidecarReadme -Encoding UTF8

$nodeModulesPath = Join-Path $sidecarDest "node_modules"
$nodeModulesIncluded = Test-Path $nodeModulesPath
$zipSizeMb = 0

$installTxt = @"
SAC (SVIL Archive Core) — Windows RC Portable Install
Version: v$Version
Build commit: $Commit
Platform: Windows x64

## 설치 방법 (포터블)
1. 이 폴더 전체를 원하는 위치에 복사합니다. (예: C:\Apps\SAC)
2. sac_app.exe 를 실행합니다.
3. 최초 실행 시 Workspace 생성/선택 화면이 표시됩니다.

## 포함 파일
- sac_app.exe — 메인 앱
- flutter_windows.dll, sqlite3.dll — 런타임
- data\ — Flutter assets
- mcp\sidecar\ — 로컬 MCP sidecar (stdio, remote 비활성)

## MCP Sidecar
- 이 패키지는 MCP sidecar를 포함합니다.
- MCP sidecar는 로컬 실행용입니다.
- remote MCP 서버를 열지 않습니다.
- 외부 AI API 호출은 기본 비활성입니다.
- 문제가 있으면 Settings > MCP / Tool Permissions에서 상태를 확인합니다.
- 포터블 폴더 전체를 이동할 때는 mcp/sidecar 폴더도 함께 유지해야 합니다.
- sidecar 실행에는 Node.js 18+ 가 필요할 수 있습니다.
- SAC는 트레이 상주를 지원합니다. 창 닫기는 tray로 숨김일 수 있습니다.
- 완전 종료는 tray menu 또는 Settings 종료 버튼에서 수행합니다.
- Windows 시작 시 자동 실행은 기본 OFF이며 사용자가 직접 켜야 합니다.
- MCP sidecar 자동 시작은 별도 옵션입니다.

## 참고
- 코드 서명 / MSI 인스톨러는 RC 범위 외입니다. ZIP/폴더 배포입니다.
- sidecar lifecycle은 앱이 관리합니다.
- 외부 API / remote MCP는 기본 비활성입니다.

## 제거
폴더를 삭제하면 됩니다. 레지스트리 설치 항목 없음.
"@
Set-Content -Path (Join-Path $dest "INSTALL.txt") -Value $installTxt -Encoding UTF8

$manifest = [ordered]@{
    product = "SAC"
    version = $Version
    commit = $Commit
    platform = "windows-x64"
    built_at = (Get-Date -Format "yyyy-MM-dd HH:mm")
    entrypoint = "sac_app.exe"
    package_type = "portable-zip"
    mcp_sidecar_included = $true
    mcp_sidecar_path = "mcp/sidecar"
    mcp_sidecar_build = "pass"
    mcp_sidecar_runtime = "local-stdio"
    mcp_sidecar_node_modules_included = $nodeModulesIncluded
    mcp_sidecar_native_binding_included = $nativeBindingIncluded
    external_api_enabled = $false
    remote_mcp_enabled = $false
    sidecar_process_managed_by_app = $true
    tray_resident_supported = $true
    windows_autostart_supported = $true
}
$manifestJson = $manifest | ConvertTo-Json -Depth 4
Set-Content -Path (Join-Path $dest "BUILD_MANIFEST.json") -Value $manifestJson -Encoding UTF8

$zipPath = Join-Path $binRoot "$pkgName.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }

# npm ci 직후 node_modules 잠금으로 Compress-Archive가 실패할 수 있어 retry 한다.
function Invoke-PortableZipArchive {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [int]$MaxAttempts = 5,
        [int]$DelaySeconds = 3
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            if (Test-Path $DestinationPath) { Remove-Item -Force $DestinationPath }
            Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath -CompressionLevel Optimal
            return
        } catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Host "Compress-Archive attempt $attempt failed (file lock?). Retrying in ${DelaySeconds}s..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

Invoke-PortableZipArchive -SourcePath $dest -DestinationPath $zipPath
$zipSizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)

Write-Host "==> Package ready"
Write-Host "Folder: $dest"
Write-Host "ZIP:    $zipPath ($zipSizeMb MB)"
Write-Host "Sidecar included: $nodeModulesIncluded (native binding: $nativeBindingIncluded)"
