param([switch]$LocalOnly, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$runtimeDirectory = Join-Path $PSScriptRoot 'runtime'
$pythonDirectory = Join-Path $runtimeDirectory 'python'
$pythonExecutable = Join-Path $pythonDirectory 'python.exe'
try {
    New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
    if (-not (Test-Path -LiteralPath $pythonExecutable)) {
        Write-Host 'Preparing Atlas+ (first run only). Downloading portable Python from python.org...'
        $pythonArchive = Join-Path $runtimeDirectory 'python.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/3.13.12/python-3.13.12-embed-amd64.zip' -OutFile $pythonArchive
        $expectedHash = '76f238f606250c87c6beac75dccd35ee99070a13490555936abb6cb64ecce3d0'
        $actualHash = (Get-FileHash -LiteralPath $pythonArchive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) { throw 'Python download checksum mismatch. Please retry.' }
        Expand-Archive -LiteralPath $pythonArchive -DestinationPath $pythonDirectory -Force
        Remove-Item -LiteralPath $pythonArchive
    }
    Write-Host 'Starting Atlas+ coordinator. Leave this window open on this computer.'
    $coordinatorArguments = @('-I', (Join-Path $PSScriptRoot 'coordinator.py'))
    if ($LocalOnly) { $coordinatorArguments += '--local-only' }
    if ($NoBrowser) { $coordinatorArguments += '--no-browser' }
    & $pythonExecutable @coordinatorArguments
    exit $LASTEXITCODE
} catch {
    Write-Host ('Unable to start: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
