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

# --- 1. 이미지 검사 ---------------------------------------------------------
# Jekyll 은 _ 로 시작하는 폴더의 파일을 _site 로 복사하지 않는다.
# 그래서 _posts 에 둔 이미지는 사이트에 안 올라가고, CI 의 htmlproofer 가
# 없는 이미지를 잡아 빌드를 통째로 실패시킨다. 2026-08 에 네 번 겪었다.
$postsDir = Join-Path $repo '_posts'
$imgExt   = '^\.(png|jpg|jpeg|gif|webp|svg)$'

$stray = @(Get-ChildItem $postsDir -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Extension -match $imgExt })

if ($stray.Count -gt 0) {
    Write-Host ""
    Write-Host "_posts 에 이미지가 있습니다. 여기 두면 빌드가 깨집니다." -ForegroundColor Red
    $stray | ForEach-Object { Write-Host "  _posts\$($_.Name)" }
    Write-Host ""
    Write-Host "  Jekyll 은 _ 로 시작하는 폴더의 파일을 사이트로 복사하지 않습니다."
    Write-Host "  assets\img\ 로 옮기고 본문 경로도 같이 고치세요."
    Write-Host ""
    Write-Host "  예)  Move-Item _posts\$($stray[0].Name) assets\img\week7-kpt.png" -ForegroundColor Cyan
    Write-Host "       ![설명](/assets/img/week7-kpt.png)" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# 글이 가리키는 그림이 실제로 있는지도 본다.
# 확장자만 틀려도(.png 로 적고 파일은 .jpg) 빌드가 깨진다. 이것도 실제로 겪었다.
$missing = @()
Get-ChildItem $postsDir -Filter '*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $md   = $_
    $text = Get-Content $md.FullName -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($text, '\((/assets/[^)\s]+)\)')) {
        $ref  = $m.Groups[1].Value
        # 윈도우는 경로에 / 도 그대로 받으므로 구분자를 바꿀 필요가 없다
        $full = Join-Path $repo $ref.TrimStart('/')
        if (-not (Test-Path $full)) { $missing += "$($md.Name)  ->  $ref" }
    }
}

if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "글이 가리키는 그림이 없습니다. 이대로 올리면 빌드가 실패합니다." -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    Write-Host "  파일 이름과 확장자가 본문과 똑같은지 확인하세요."
    Write-Host ""
    exit 1
}

# --- 2. 올릴 게 있는지 ------------------------------------------------------
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

# --- 3. 커밋 메시지 ---------------------------------------------------------
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

# --- 4. add / commit / push -------------------------------------------------
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
