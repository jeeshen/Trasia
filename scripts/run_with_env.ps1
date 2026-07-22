$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env.local"

if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Host "Missing .env.local"
  Write-Host "Create it from .env.local.example and paste your keys."
  exit 1
}

Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line.Length -eq 0 -or $line.StartsWith("#")) {
    return
  }

  $parts = $line.Split("=", 2)
  if ($parts.Length -eq 2) {
    [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
  }
}

if (-not $env:SUPABASE_URL) {
  Write-Host "SUPABASE_URL is missing in .env.local"
  exit 1
}

if (-not $env:SUPABASE_ANON_KEY) {
  Write-Host "SUPABASE_ANON_KEY is missing in .env.local"
  exit 1
}

$flutter = "C:\flutter\bin\flutter.bat"

$args = @(
  "run",
  "-t",
  "lib\main.dart",
  "--dart-define=SUPABASE_URL=$env:SUPABASE_URL",
  "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY"
)

if ($env:GOOGLE_MAPS_API_KEY) {
  $args += "--dart-define=GOOGLE_MAPS_API_KEY=$env:GOOGLE_MAPS_API_KEY"
}

& $flutter @args
