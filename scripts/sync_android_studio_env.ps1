$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root ".env.local"
$runConfigDir = Join-Path $root ".idea\runConfigurations"
$runConfigFile = Join-Path $runConfigDir "Trasia_env.xml"

if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Host "Missing .env.local"
  exit 1
}

$values = @{}
Get-Content -LiteralPath $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line.Length -eq 0 -or $line.StartsWith("#")) {
    return
  }

  $parts = $line.Split("=", 2)
  if ($parts.Length -eq 2) {
    $values[$parts[0].Trim()] = $parts[1].Trim()
  }
}

$required = @("SUPABASE_URL", "SUPABASE_ANON_KEY")
foreach ($key in $required) {
  if (-not $values[$key]) {
    Write-Host "$key is missing in .env.local"
    exit 1
  }
}

$args = @(
  "--dart-define=SUPABASE_URL=$($values["SUPABASE_URL"])",
  "--dart-define=SUPABASE_ANON_KEY=$($values["SUPABASE_ANON_KEY"])"
)

if ($values["GOOGLE_MAPS_API_KEY"]) {
  $args += "--dart-define=GOOGLE_MAPS_API_KEY=$($values["GOOGLE_MAPS_API_KEY"])"
}

New-Item -ItemType Directory -Force -Path $runConfigDir | Out-Null

$escapedArgs = [System.Security.SecurityElement]::Escape(($args -join " "))
$xml = @"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="Trasia (.env.local)" type="FlutterRunConfigurationType" factoryName="Flutter">
    <option name="additionalArgs" value="$escapedArgs" />
    <option name="filePath" value="`$PROJECT_DIR`$/lib/main.dart" />
    <method v="2" />
  </configuration>
</component>
"@

Set-Content -LiteralPath $runConfigFile -Value $xml
Write-Host "Updated $runConfigFile"
