param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LessPassArguments
)

$ErrorActionPreference = 'Stop'
$lessPassCommand = Get-Command -Name lesspass -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
    throw 'The APPDATA environment variable is not set.'
}

Add-Type -AssemblyName System.Security

$configDirectory = Join-Path $env:APPDATA 'lesspass'
$configPath = Join-Path $configDirectory 'config.json'
$propertyName = 'EncryptedSecret'
$config = $null
$hasStoredPassword = $false

if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ($null -eq $config -or $config -isnot [PSCustomObject]) {
        throw "Expected a JSON object in '$configPath'."
    }

    $passwordProperty = $config.PSObject.Properties[$propertyName]
    if ($null -ne $passwordProperty) {
        if ([string]::IsNullOrWhiteSpace([string]$passwordProperty.Value)) {
            throw "The '$propertyName' value in '$configPath' is empty."
        }

        $encryptedBytes = [Convert]::FromBase64String([string]$passwordProperty.Value)
        $plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        try {
            $plainPassword = [System.Text.Encoding]::UTF8.GetString($plainBytes)
        }
        finally {
            [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        }
        $hasStoredPassword = $true
    }
}

$environmentVariableName = 'LESSPASS_MASTER_PASSWORD'
$processEnvironment = [Environment]::GetEnvironmentVariables([EnvironmentVariableTarget]::Process)
$hadPreviousPassword = $processEnvironment.Contains($environmentVariableName)
$previousPassword = [Environment]::GetEnvironmentVariable(
    $environmentVariableName,
    [EnvironmentVariableTarget]::Process
)

if (-not $hasStoredPassword) {
    $securePassword = Read-Host -Prompt 'Enter the LessPass master password' -AsSecureString
    if ($securePassword.Length -eq 0) {
        $securePassword.Dispose()
        throw 'The master password cannot be empty.'
    }

    $bstr = [IntPtr]::Zero
    $plainBytes = $null
    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $plainBytes = [System.Text.Encoding]::UTF8.GetBytes($plainPassword)
        $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
            $plainBytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        $encodedPassword = [Convert]::ToBase64String($encryptedBytes)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
        if ($null -ne $plainBytes) {
            [Array]::Clear($plainBytes, 0, $plainBytes.Length)
        }
        $securePassword.Dispose()
    }

    if ($null -eq $config) {
        New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
        $config = [PSCustomObject]@{}
    }

    $config | Add-Member -MemberType NoteProperty -Name $propertyName -Value $encodedPassword -Force
    $config | Add-Member -MemberType NoteProperty -Name 'LastUpdated' -Value (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -Force
    $json = ConvertTo-Json -InputObject $config -Depth 100
    $temporaryPath = Join-Path $configDirectory ([IO.Path]::GetRandomFileName())
    $backupPath = "$temporaryPath.bak"
    try {
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        [IO.File]::WriteAllText($temporaryPath, $json, $utf8WithoutBom)

        if (Test-Path -LiteralPath $configPath -PathType Leaf) {
            [IO.File]::Replace($temporaryPath, $configPath, $backupPath)
        }
        else {
            [IO.File]::Move($temporaryPath, $configPath)
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
}

try {
    [Environment]::SetEnvironmentVariable(
        $environmentVariableName,
        $plainPassword,
        [EnvironmentVariableTarget]::Process
    )
    & $lessPassCommand @LessPassArguments
}
finally {
    if ($hadPreviousPassword) {
        [Environment]::SetEnvironmentVariable(
            $environmentVariableName,
            $previousPassword,
            [EnvironmentVariableTarget]::Process
        )
    }
    else {
        [Environment]::SetEnvironmentVariable(
            $environmentVariableName,
            $null,
            [EnvironmentVariableTarget]::Process
        )
    }
    $plainPassword = $null
}