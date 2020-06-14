#
# カレントディレクトリの画像ファイル(*.jpg,*.jpeg,*.png)のファイル名をリネームする。
#
# リネーム後のファイル名
#   YYYYMMDD_nn
#   20200614_01
#
# リネーム後のファイル名は現在日付を開始日として連番01～99ごとに日付を1日進める。
# ファイル数が110個の場合は以下のようになる。
#   20200614_01 ～ 20200614_99
#   20200615_01 ～ 20200615_10
#
# ・ハッシュ値を比較して重複した画像が存在する場合は処理を中断する。
# ・ファイル名を1からの連番に変更してから正式なファイル名にリネームする。
#   これによりリネーム後のファイル名が既に存在していた場合も名前を付けなおすことができる。
#     aaa.jpg         -> 1.jpg -> 20200614_01.jpg
#     20200614_01.jpg -> 2.jpg -> 20200614_02.jpg
#     bbb.jpg         -> 3.jpg -> 20200614_03.jpg
# ・拡張子は小文字に統一する。"jpeg" は "jpg" に変更する。
#

function Get-SubList {
  <#
    .Description
    引数のリストの部分リストを取得する。

    $SrcList 部分リストを取得するリスト
    $FromIndex 開始インデックス(このインデックスを含む)
    $ToIndex 終了インデックス(このインデックスを含まない)
  #>
  param($SrcList, [int32]$FromIndex, [int32]$ToIndex)

  if (
    ($FromIndex -lt 0) -or
    (($SrcList.Count - 1) -lt $FromIndex) -or
    ($ToIndex -lt 0) -or
    ($SrcList.Count -lt $ToIndex) -or
    ($ToIndex -lt $FromIndex)
  ) {
    throw "IllegalArgument SrcList.Count[$($SrcList.Count)] FromIndex[$($FromIndex)] ToIndex[$($ToIndex)]"
  }

  $SubList = @()
  for ($i = $FromIndex; $i -lt $ToIndex; $i++) {
    $SubList += $SrcList[$i]
  }

  $SubList
}

function Get-RenameFileNameList {
  <#
    .Description
    リネーム後のファイル名のリストを取得する。

    現在日付を開始日として連番01～99ごとに日付を1日進める。
    YYYYMMDD_nn

    $Countが110の場合は以下のようになる。
    20200614_01 ～ 20200614_99
    20200615_01 ～ 20200615_10

    $Count 作成するファイル名の数
  #>
  param ([int32]$Count)

  # 1日の連番の最大数
  $NumberOfLimitOfDay = 99
  # 最終日の連番の最大数に満たない端数
  $NumberOfLimitOfLastDay = $Count % $NumberOfLimitOfDay

  # 日付の数
  $DateCount = [int32]($Count / $NumberOfLimitOfDay)
  $DateCount += ($NumberOfLimitOfLastDay -gt 0) ? 1 : 0

  # 日付文字列(YYYYMMDD)のリストを作成する。
  $DateList = @()
  for ($i = 0; $i -lt $DateCount; $i++) {
    $DateList += (Get-Date).AddDays($i) | Get-Date -Format "yyyyMMdd"
  }

  # ファイル名(YYYYMMDD_nn)のリストを作成する。
  $FileNameList = @()
  # 日付文字列(YYYYMMDD)ループ
  foreach ($Date in $DateList) {
    # 連番(nn)ループ
    for ($i = 1; $i -le $NumberOfLimitOfDay; $i++) {
      $FileNameList += $Date + "_" + ([string]$i).PadLeft(([string]$NumberOfLimitOfDay).Length, "0")
    }
  }

  # ファイル名(YYYYMMDD_nn)のリストから最終日の連番の数を端数に合わせる。
  #
  # ファイル名を110個作成する場合は1日の連番の最大数で作成してから最終日を端数に合わせて減らす。
  #   20200614_01 ～ 20200614_99
  #   20200615_01 ～ 20200615_99
  #     ↓
  #   20200614_01 ～ 20200614_99
  #   20200615_01 ～ 20200615_10
  if ($NumberOfLimitOfLastDay -ne 0) {
    $LastIndex = ($FileNameList.Count - 1) - ($NumberOfLimitOfDay - $NumberOfLimitOfLastDay)
    $FileNameList = Get-SubList -SrcList $FileNameList -FromIndex 0 -ToIndex ($LastIndex + 1)
  }

  # 戻り値
  $FileNameList
}

function Rename-TemporaryFileName {
  <#
    .Description
    ファイル名を1からの連番に変更する。

    $FileList ファイル名を変更するファイルのリスト
  #>
  param ($FileList)

  $TemporaryFileIndex = 1
  $TemporaryFileName = ""
  $TemporaryPath = ""

  foreach ($File in $FileList) {
    # 既存のファイル名と重ならなくなるまで連番を増やす。
    while ($true) {
      $TemporaryDirectoryPath = Split-Path -Path $File.FullName
      $TemporaryFileExtension = (Split-Path -Path $File.FullName -Extension).ToLower()
      if ($TemporaryFileExtension -eq ".jpeg") {
        $TemporaryFileExtension = ".jpg"
      }
      $TemporaryFileName = "$($TemporaryFileIndex)$($TemporaryFileExtension)"
      $TemporaryPath = Join-Path -Path $TemporaryDirectoryPath -ChildPath $TemporaryFileName

      if (Test-Path -Path $TemporaryPath) {
        $TemporaryFileIndex++
      }
      else {
        break
      }
    }

    $File | Rename-Item -NewName $TemporaryFileName
  }
}

# ====================================================================================================
# 処理の開始
# ====================================================================================================
"Start."

# カレントディレクトリの画像ファイルを取得する。
$FileList = Get-ChildItem -Path .\* -Include *.jpg,*.jpeg,*.png
"1 FileList.Count=" + $FileList.Count

if ($FileList.Count -eq 0) {
  "No files."
  "Abort."
  exit
}

# 重複したファイルが存在する場合は処理を中断する。
$FileHashMap1 = @{}
foreach ($File in $FileList) {
  $Hash = (Get-FileHash $File.FullName).Hash
  if (!$FileHashMap1.ContainsKey($Hash)) {
    $FileHashMap1.Add($Hash, $File)
  }
  else {
    "Duplicate file 1[" + $FileHashMap1[$Hash].FullName + "]"
    "Duplicate file 2[" + $File.FullName + "]"
  }
}
"1 FileHashMap1.Count=" + $FileHashMap1.Count

if ($FileList.Count -ne $FileHashMap1.Count) {
  "Duplicate file found."
  "Abort."
  exit 1
}

# 現在のファイル名を連番で置き換えてリネームする新しいファイル名と重ならないようにする。
Rename-TemporaryFileName -FileList $FileList

# リネームする新しいファイル名を生成する。
# ・要素が1つの場合でも強制的に配列として扱う。
$RenameFileNameList = @(Get-RenameFileNameList -Count $FileList.Count)

# カレントディレクトリの画像ファイルを再取得してファイル名をリネームする。
$FileList = Get-ChildItem -Path .\* -Include *.jpg,*.png
"2 FileList.Count=" + $FileList.Count
for ($i = 0; $i -lt $FileList.Count; $i++) {
  $FileExtension = Split-Path -Path $FileList[$i].FullName -Extension
  $FileList[$i] | Rename-Item -NewName "$($RenameFileNameList[$i])$($FileExtension)"
}

# 全てのファイルの内容が変更されていないことを検証する。
$FileList = Get-ChildItem -Path .\* -Include *.jpg,*.png
$FileHashMap2 = @{}
foreach ($File in $FileList) {
  $Hash = (Get-FileHash $File.FullName).Hash
  if (!$FileHashMap2.ContainsKey($Hash)) {
    $FileHashMap2.Add($Hash, $File)
  }
  else {
    "Duplicate file 1[" + $FileHashMap2[$Hash].FullName + "]"
    "Duplicate file 2[" + $File.FullName + "]"
  }
}
"2 FileHashMap2.Count=" + $FileHashMap2.Count

foreach ($Hash in $FileHashMap2.Keys) {
  if (!$FileHashMap1.ContainsKey($Hash)) {
    "File hash is changed."
    "Renamed file is[" + $FileHashMap2[$Hash].FullName + "]"
    "Abort."
    exit 1
  }
}

# 正常終了
"End."