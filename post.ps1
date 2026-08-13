# 새 글 뼈대를 만든다.
#
#   .\post.ps1 week-3 "W3 회고 - 자바 입문을 끝냈다" WIL
#
# 이 스크립트가 막아주는 것 두 가지 (둘 다 실제로 겪은 사고다)
#   1) date 를 미래로 적으면 글이 아예 안 올라간다  -> 항상 「지금」을 박는다
#   2) 파일명에 한글을 쓰면 주소가 깨진다            -> 영문 슬러그만 받는다

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Slug,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Title,

    [Parameter(Position = 2)]
    [string]$Category = 'WIL'
)

$ErrorActionPreference = 'Stop'

# 카테고리는 여섯 개뿐이다. 늘리면 사이드바가 목록이 되어버린다.
$AllowedCategories = @('WIL', 'Java', 'Spring', '프로젝트', 'CS', '회고')

# --- 1. 슬러그 검사 (영문 소문자 / 숫자 / 하이픈) ---------------------------
if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    Write-Host ""
    Write-Host "슬러그는 영문 소문자 · 숫자 · 하이픈만 됩니다: '$Slug'" -ForegroundColor Red
    Write-Host "  한글을 쓰면 글 주소가 깨집니다. 제목만 한글로 쓰세요."
    Write-Host "  예) .\post.ps1 week-3 `"W3 회고`" WIL"
    Write-Host ""
    exit 1
}

# --- 2. 카테고리 검사 -------------------------------------------------------
if ($AllowedCategories -notcontains $Category) {
    Write-Host ""
    Write-Host "'$Category' 는 정해둔 카테고리가 아닙니다." -ForegroundColor Red
    Write-Host "  쓸 수 있는 것: $($AllowedCategories -join ' / ')"
    Write-Host ""
    exit 1
}

# --- 3. 경로 만들기 ---------------------------------------------------------
$now      = Get-Date
$postsDir = Join-Path $PSScriptRoot '_posts'
$fileName = "{0}-{1}.md" -f $now.ToString('yyyy-MM-dd'), $Slug
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

# --- 4. 내용 만들기 ---------------------------------------------------------
# date 는 「지금」. 미래로 적으면 Jekyll 이 발행을 미뤄서 글이 사라진 것처럼 보인다.
$date = $now.ToString('yyyy-MM-dd HH:mm:ss') + ' +0900'

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
categories: [$Category]
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
Write-Host "  분류: $Category"
Write-Host "  날짜: $date"
Write-Host ""
Write-Host "글을 다 쓰면:  .\publish.ps1" -ForegroundColor Cyan
Write-Host ""
