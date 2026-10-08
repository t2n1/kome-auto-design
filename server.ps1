# Kome flyer - local web server (PowerShell, no install needed)
# Serves this folder at http://localhost:8765/ and opens the browser.
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Split-Path -Parent $MyInvocation.MyCommand.Path))
if (-not $root.EndsWith('\')) { $root = $root + '\' }

$mime = @{
  '.html' = 'text/html; charset=utf-8'; '.htm' = 'text/html; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'; '.txt' = 'text/plain; charset=utf-8'
  '.csv'  = 'text/csv; charset=utf-8'
  '.png'  = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'
  '.gif'  = 'image/gif'; '.svg' = 'image/svg+xml'; '.avif' = 'image/avif'; '.bmp' = 'image/bmp'
  '.ico'  = 'image/x-icon'; '.woff2' = 'font/woff2'
  '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
}

$listener = $null
$port = 0
foreach ($p in 8765..8785) {
  try {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://localhost:$p/")
    $l.Start()
    $listener = $l
    $port = $p
    break
  } catch { }
}
if ($null -eq $listener) {
  Write-Host 'Khong mo duoc may chu (cong 8765-8785 deu dang ban).'
  Write-Host 'Ban co the mo truc tiep file index.html bang Chrome hoac Edge.'
  exit 1
}

$url = "http://localhost:$port/"
Write-Host ''
Write-Host '  Flyer gia khuyen mai dang chay tai:' $url
Write-Host '  GIU cua so nay mo trong luc dung. Dong cua so de tat.'
if ($port -ne 8765) { Write-Host '  Luu y: cong 8765 dang ban nen dung cong' $port '- anh da tai len trinh duyet o lan truoc se khong hien.' }
Write-Host ''
Start-Process $url

function Send-Bytes($res, [byte[]]$bytes, [string]$type) {
  $res.ContentType = $type
  $res.AddHeader('Cache-Control', 'no-store')
  $res.ContentLength64 = $bytes.Length
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
}

while ($listener.IsListening) {
  try { $ctx = $listener.GetContext() } catch { break }
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $rawPath = $req.Url.AbsolutePath
    $rel = [System.Uri]::UnescapeDataString($rawPath).TrimStart('/').Replace('/', '\')
    $full = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $rel))
    $rootNoSlash = $root.TrimEnd('\')
    if (-not ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase) -or $full.Equals($rootNoSlash, [System.StringComparison]::OrdinalIgnoreCase))) {
      $res.StatusCode = 403
    }
    elseif ([System.IO.Directory]::Exists($full)) {
      $index = [System.IO.Path]::Combine($full, 'index.html')
      if ($rel -eq '' -and [System.IO.File]::Exists($index)) {
        Send-Bytes $res ([System.IO.File]::ReadAllBytes($index)) 'text/html; charset=utf-8'
      }
      elseif (-not $rawPath.EndsWith('/')) {
        $res.Redirect($rawPath + '/')
      }
      else {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('<!doctype html><meta charset="utf-8"><title>Danh sach</title><ul>')
        foreach ($f in (Get-ChildItem -LiteralPath $full -File)) {
          [void]$sb.Append('<li><a href="' + [System.Uri]::EscapeDataString($f.Name) + '">' + [System.Net.WebUtility]::HtmlEncode($f.Name) + '</a></li>')
        }
        [void]$sb.Append('</ul>')
        Send-Bytes $res ([System.Text.Encoding]::UTF8.GetBytes($sb.ToString())) 'text/html; charset=utf-8'
      }
    }
    elseif ([System.IO.File]::Exists($full)) {
      $ext = [System.IO.Path]::GetExtension($full).ToLowerInvariant()
      $type = $mime[$ext]
      if (-not $type) { $type = 'application/octet-stream' }
      Send-Bytes $res ([System.IO.File]::ReadAllBytes($full)) $type
    }
    else {
      $res.StatusCode = 404
    }
  } catch {
    try { $res.StatusCode = 500 } catch { }
  } finally {
    try { $res.Close() } catch { }
  }
}
