# 새 글 뼈대를 만든다.
#
#   .\post.ps1 week-3 "W3 회고 - 자바 입문을 끝냈다" WIL
#   .\post.ps1 malloc-macro "malloc 매크로" Krafton-Jungle malloc -Date 2026-04-14
#                                           ↑상위          ↑하위      ↑원본 날짜
#
# 이 스크립트가 막아주는 것 (전부 실제로 겪었거나 겪을 뻔한 사고다)
#   1) date 를 미래로 적으면 글이 아예 안 올라간다  -> 미래 날짜를 거부한다
#   2) 파일명에 한글을 쓰면 주소가 깨진다            -> 영문 슬러그만 받는다
#   3) 상위 분류 이름을 하위로 쓰면 사이드바가 깨진다
#      예) [Krafton-Jungle, WIL] 은 WIL 이 자기 자신의 하위로 들어간다 (WIL > WIL)
#      -> 같은 이름이거나 하위에 상위 이름을 쓰면 멈춘다

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Slug,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Title,

    [Parameter(Position = 2)]
    [string]$Category = 'WIL',

    # 하위 분류 (선택). 주면 categories: [상위, 하위] 가 된다.
    [Parameter(Position = 3)]
    [string]$SubCategory,

    # 원본 날짜 (선택, YYYY-MM-DD). 티스토리 글을 옮길 때 쓴다. 과거만 받는다.
    [string]$Date
)

$ErrorActionPreference = 'Stop'

# 카테고리는 여덟 개뿐이다. 늘리면 사이드바가 목록이 되어버린다.
# 이 검사는 상위에만 건다 — 하위는 「필요해지면 그때 붙인다」로 정해뒀다.
# Krafton-Jungle 은 20편에서 멈추는 아카이브라 예외로 뒀다 (2026-08-17 추가).
$AllowedCategories = @('WIL', 'Java', 'Spring', '프로젝트', 'CS', '회고', 'Krafton-Jungle', '자격증')

# --- 1. 슬러그 검사 (영문 소문자 / 숫자 / 하이픈) ---------------------------
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Host ""
    Write-Host "슬러그는 영문 소문자 · 숫자 · 하이픈만 됩니다: '$Slug'" -ForegroundColor Red
    Write-Host "  한글을 쓰면 글 주소가 깨집니다. 제목만 한글로 쓰세요."
    Write-Host "  예) .\post.ps1 week-3 `"W3 회고`" WIL"
    Write-Host ""
    exit 1
}

# --- 2. 분류 검사 -----------------------------------------------------------
if ($AllowedCategories -notcontains $Category) {
    Write-Host ""
    Write-Host "'$Category' 는 정해둔 카테고리가 아닙니다." -ForegroundColor Red
    Write-Host "  쓸 수 있는 것: $($AllowedCategories -join ' / ')"
    Write-Host ""
    exit 1
}

if ($SubCategory -and $SubCategory -eq $Category) {
    Write-Host ""
    Write-Host "상위와 하위가 같습니다: '$Category'" -ForegroundColor Red
    Write-Host "  하위를 안 쓰려면 네 번째 인자를 아예 빼세요."
    Write-Host ""
    exit 1
}

if ($SubCategory -and $AllowedCategories -contains $SubCategory) {
    Write-Host ""
    Write-Host "'$SubCategory' 는 상위 분류 이름입니다. 하위로는 쓸 수 없습니다." -ForegroundColor Red
    Write-Host "  사이드바가 그 이름을 자기 자신의 하위로 그립니다 ($SubCategory > $SubCategory)."
    Write-Host "  하위를 모을 때 categories[1] 을 긁어모으는데, 그 글이 상위 목록에도 들어가기 때문입니다."
    Write-Host ""
    exit 1
}

# --- 3. 날짜 정하기 ---------------------------------------------------------
# 미래 날짜면 Jekyll 이 발행을 미뤄서 글이 사라진 것처럼 보인다. 그래서 과거만 받는다.
$now = Get-Date

if ($Date) {
    $parsed = [datetime]::MinValue
    $ok = [datetime]::TryParseExact(
        $Date, 'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$parsed
    )

    if (-not $ok) {
        Write-Host ""
        Write-Host "날짜 형식이 아닙니다: '$Date'" -ForegroundColor Red
        Write-Host "  YYYY-MM-DD 로 쓰세요. 예) -Date 2026-03-07"
        Write-Host ""
        exit 1
    }

    if ($parsed.Date -gt $now.Date) {
        Write-Host ""
        Write-Host "미래 날짜입니다: '$Date'" -ForegroundColor Red
        Write-Host "  Jekyll 은 미래 글을 발행하지 않습니다. 빌드는 되는데 글만 안 보입니다."
        Write-Host "  오늘($($now.ToString('yyyy-MM-dd'))) 이거나 그 이전만 됩니다."
        Write-Host ""
        exit 1
    }

    # 원본 글에는 시각 정보가 없으니 오전 10시로 둔다.
    # 다만 오늘 날짜를 준 경우 10시가 아직 안 됐을 수 있으므로 지금 시각으로 눌러둔다.
    $stamp = $parsed.Date.AddHours(10)
    if ($stamp -gt $now) { $stamp = $now }
}
else {
    $stamp = $now
}

# --- 4. 경로 만들기 ---------------------------------------------------------
$postsDir = Join-Path $PSScriptRoot '_posts'
$fileName = "{0}-{1}.md" -f $stamp.ToString('yyyy-MM-dd'), $Slug
$path     = Join-Path $postsDir $fileName

if (-not (Test-Path $postsDir)) {
    Write-Host "_posts 폴더가 없습니다: $postsDir" -ForegroundColor Red
    exit 1
}

if (Test-Path $path) {
    Write-Host ""
    Write-Host "이미 있는 파일입니다. 덮어쓰지 않았습니다." -ForegroundColor Yellow
    Write-Host "  $path"
    Write-Host "  다른 슬러그를 쓰거나 기존 파일을 여세요."
    Write-Host ""
    exit 1
}

# 이미 쓰고 있는 하위 분류를 모은다. 막지는 않고 오타가 눈에 보이게만 한다.
$existingSubs = @()
Get-ChildItem $postsDir -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
    foreach ($line in (Get-Content $_.FullName -TotalCount 10 -Encoding UTF8)) {
        if ($line -match '^categories:\s*\[\s*[^,\]]+\s*,\s*([^\]]+?)\s*\]') {
            $existingSubs += $matches[1]
        }
    }
}
$existingSubs = @($existingSubs | Sort-Object -Unique)

if ($SubCategory -and $existingSubs.Count -gt 0 -and $existingSubs -notcontains $SubCategory) {
    Write-Host ""
    Write-Host "'$SubCategory' 는 처음 쓰는 하위 분류입니다." -ForegroundColor Yellow
    Write-Host "  이미 쓰고 있는 것: $($existingSubs -join ' / ')"
    Write-Host "  오타가 아니라면 그대로 두세요. 새 하위 분류가 만들어집니다."
    Write-Host ""
}

# --- 5. 내용 만들기 ---------------------------------------------------------
$date = $stamp.ToString('yyyy-MM-dd HH:mm:ss') + ' +0900'

if ($SubCategory) {
    $categoryLine = "[$Category, $SubCategory]"
}
else {
    $categoryLine = "[$Category]"
}

if ($Category -eq 'WIL') {
    $body = @"
## 이번 주 목표

-

## 어디까지 어떻게 시도했는가

-

## 다음 주에 이어서 할 것

-
"@
}
else {
    $body = @"
##

"@
}

$content = @"
---
title: $Title
date: $date
categories: $categoryLine
tags: []
---

$body
"@

# BOM 없는 UTF-8 로 써야 한다.
# Set-Content -Encoding utf8 은 BOM 을 붙이는데, 그러면 Jekyll 이 첫 --- 를 못 읽는다.
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)

Write-Host ""
Write-Host "만들었습니다" -ForegroundColor Green
Write-Host "  $path"
Write-Host "  제목: $Title"
Write-Host "  분류: $categoryLine"
Write-Host "  날짜: $date"
if ($Date) {
    Write-Host "        (원본 날짜로 올립니다 — 홈 맨 위가 아니라 그 날짜 자리에 들어갑니다)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "글을 다 쓰면:  .\publish.ps1" -ForegroundColor Cyan
Write-Host ""
