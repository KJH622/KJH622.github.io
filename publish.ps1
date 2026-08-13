# 쓴 글을 블로그에 올린다 (add -> commit -> push).
#
#   .\publish.ps1
#   .\publish.ps1 "커밋 메시지를 직접 쓰고 싶을 때"
#
# 메시지를 안 주면 새로 추가된 글의 제목을 읽어서 만든다.
# 커밋에 AI 표기(Co-Authored-By 등)는 절대 붙이지 않는다.

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Message
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

# --- 1. 올릴 게 있는지 ------------------------------------------------------
$status = git -C $repo status --porcelain
if (-not $status) {
    Write-Host ""
    Write-Host "올릴 게 없습니다. 바뀐 파일이 하나도 없어요." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

Write-Host ""
Write-Host "바뀐 파일" -ForegroundColor Cyan
$status | ForEach-Object { Write-Host "  $_" }

# --- 2. 커밋 메시지 ---------------------------------------------------------
if (-not $Message) {
    # 새로 생긴(A/??) _posts 파일의 title 을 읽어 메시지를 만든다
    $newPost = $status |
        Where-Object { $_ -match '^(\?\?|A ).*_posts/' } |
        Select-Object -First 1

    if ($newPost) {
        $rel  = ($newPost -replace '^..\s+', '').Trim('"')
        $full = Join-Path $repo $rel
        if (Test-Path $full) {
            $titleLine = Get-Content $full -Encoding UTF8 |
                Select-Object -First 10 |
                Where-Object { $_ -match '^title:\s*(.+)$' } |
                Select-Object -First 1
            if ($titleLine -and $titleLine -match '^title:\s*(.+)$') {
                $Message = "글 추가: " + $matches[1].Trim()
            }
        }
    }

    if (-not $Message) {
        $Message = "블로그 업데이트 " + (Get-Date -Format 'yyyy-MM-dd')
    }
}

Write-Host ""
Write-Host "커밋 메시지: $Message" -ForegroundColor Cyan

# --- 3. add / commit / push -------------------------------------------------
# 한글 커밋 메시지가 깨지지 않도록 임시 파일로 넘긴다
git -C $repo add -A
if ($LASTEXITCODE -ne 0) { Write-Host "git add 실패" -ForegroundColor Red; exit 1 }

$msgFile   = Join-Path ([System.IO.Path]::GetTempPath()) ("blogmsg-" + [guid]::NewGuid().ToString() + ".txt")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($msgFile, $Message, $utf8NoBom)

try {
    git -C $repo commit -F $msgFile
    if ($LASTEXITCODE -ne 0) { Write-Host "커밋 실패" -ForegroundColor Red; exit 1 }
}
finally {
    Remove-Item $msgFile -ErrorAction SilentlyContinue
}

git -C $repo push
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "푸시 실패. 인터넷 연결을 확인하고 다시 .\publish.ps1 을 실행하세요." -ForegroundColor Red
    Write-Host "(커밋은 이미 됐으니 글은 안 없어집니다)"
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "올렸습니다" -ForegroundColor Green
Write-Host "  https://kjh622.github.io"
Write-Host ""
Write-Host "  약 40초 뒤에 반영됩니다."
Write-Host "  안 보이면 브라우저에서 Ctrl + Shift + R 로 새로고침하세요."
Write-Host ""
