param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("Store", "Sideload")]
  [string]$Mode,

  [string]$CertificatePath,
  [string]$CertificatePassword
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Find-WindowsSdkTool {
  param([Parameter(Mandatory = $true)][string]$Name)

  $tool = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits" -Recurse -Filter $Name |
    Where-Object { $_.FullName -match "\\x64\\$([regex]::Escape($Name))$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
  if (-not $tool) {
    throw "$Name was not found in the installed Windows SDK."
  }
  return $tool
}

function Get-MsixVersion {
  $versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)(?:\+[0-9]+)?\s*$' |
    Select-Object -First 1
  if (-not $versionLine) {
    throw "pubspec.yaml version must use major.minor.patch with an optional +build suffix."
  }

  $components = @(
    [int]$versionLine.Matches[0].Groups[1].Value,
    [int]$versionLine.Matches[0].Groups[2].Value,
    [int]$versionLine.Matches[0].Groups[3].Value
  )
  if ($components[0] -eq 0) {
    throw "The MSIX major version must be greater than zero."
  }
  foreach ($component in $components) {
    if ($component -lt 0 -or $component -gt 65535) {
      throw "Each MSIX version component must be between 0 and 65535."
    }
  }
  return "$($components[0]).$($components[1]).$($components[2]).0"
}

function Get-MsixConfigValue {
  param([Parameter(Mandatory = $true)][string]$Name)

  $line = Select-String -Path "pubspec.yaml" -Pattern "^  $([regex]::Escape($Name)):\s*(.+?)\s*$" |
    Select-Object -First 1
  if (-not $line -or [string]::IsNullOrWhiteSpace($line.Matches[0].Groups[1].Value)) {
    throw "pubspec.yaml msix_config.$Name is required."
  }
  return $line.Matches[0].Groups[1].Value
}

function Get-SideloadPublisher {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Password
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Sideload certificate was not found at $Path."
  }
  if ([string]::IsNullOrEmpty($Password)) {
    throw "CertificatePassword is required for Sideload mode."
  }

  $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $Path,
    $Password,
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
  )
  try {
    if (-not $certificate.HasPrivateKey) {
      throw "The sideload certificate does not contain a private key."
    }
    return $certificate.Subject
  } finally {
    $certificate.Dispose()
  }
}

function Assert-MsixContents {
  param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$ExpectedIdentity,
    [Parameter(Mandatory = $true)][string]$ExpectedPublisher,
    [Parameter(Mandatory = $true)][string]$ExpectedVersion,
    [Parameter(Mandatory = $true)][bool]$MustBeSigned
  )

  if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    throw "Expected MSIX was not created: $PackagePath"
  }

  $makeAppx = Find-WindowsSdkTool -Name "makeappx.exe"
  $temporaryRoot = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    [IO.Path]::GetTempPath()
  } else {
    $env:RUNNER_TEMP
  }
  $unpackDirectory = Join-Path $temporaryRoot "vagina-msix-$Mode"
  Remove-Item -LiteralPath $unpackDirectory -Recurse -Force -ErrorAction SilentlyContinue
  & $makeAppx unpack /p $PackagePath /d $unpackDirectory /o | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed to unpack $PackagePath."
  }

  [xml]$manifest = Get-Content -LiteralPath (Join-Path $unpackDirectory "AppxManifest.xml") -Raw
  $namespace = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
  $namespace.AddNamespace("f", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
  $namespace.AddNamespace("uap", "http://schemas.microsoft.com/appx/manifest/uap/windows10")

  $identity = $manifest.SelectSingleNode("/f:Package/f:Identity", $namespace)
  if (-not $identity) {
    throw "MSIX manifest does not contain Package/Identity."
  }
  $actualIdentity = $identity.GetAttribute("Name")
  $actualPublisher = $identity.GetAttribute("Publisher")
  $actualVersion = $identity.GetAttribute("Version")
  if ($actualIdentity -ne $ExpectedIdentity) {
    throw "MSIX identity '$actualIdentity' does not match '$ExpectedIdentity'."
  }
  if ($actualPublisher -ne $ExpectedPublisher) {
    throw "MSIX Publisher '$actualPublisher' does not match '$ExpectedPublisher'."
  }
  if ($actualVersion -ne $ExpectedVersion) {
    throw "MSIX version '$actualVersion' does not match '$ExpectedVersion'."
  }

  $protocol = $manifest.SelectSingleNode("/f:Package/f:Applications/f:Application/f:Extensions/uap:Extension[@Category='windows.protocol']/uap:Protocol[@Name='app.aoki.yuki.vagina']", $namespace)
  if (-not $protocol) {
    throw "MSIX manifest does not declare the app.aoki.yuki.vagina OAuth protocol."
  }

  foreach ($requiredPath in @("vagina.exe", "flutter_windows.dll", "data\flutter_assets")) {
    if (-not (Test-Path -LiteralPath (Join-Path $unpackDirectory $requiredPath))) {
      throw "MSIX payload is missing $requiredPath."
    }
  }

  $signature = Get-AuthenticodeSignature -LiteralPath $PackagePath
  if ($MustBeSigned) {
    if ($signature.Status -eq "NotSigned" -or -not $signature.SignerCertificate) {
      throw "Sideload MSIX does not contain an Authenticode signature."
    }
    Write-Host "Sideload signature status: $($signature.Status)"
    Write-Host "Sideload signer: $($signature.SignerCertificate.Subject)"
  } elseif ($signature.Status -ne "NotSigned") {
    throw "Store MSIX must be unsigned before Partner Center submission, but its signature status is $($signature.Status)."
  }
}

$identityName = Get-MsixConfigValue -Name "identity_name"
$storePublisher = Get-MsixConfigValue -Name "publisher"
$publisherDisplayName = Get-MsixConfigValue -Name "publisher_display_name"
$version = Get-MsixVersion
$outputDirectory = Join-Path "build\windows\msix" $Mode.ToLowerInvariant()
$outputName = "vagina-$($Mode.ToLowerInvariant())-$version-x64"
$packagePath = Join-Path $outputDirectory "$outputName.msix"
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$publisher = if ($Mode -eq "Store") {
  $storePublisher
} else {
  Get-SideloadPublisher -Path $CertificatePath -Password $CertificatePassword
}

$arguments = @(
  "run", "msix:create",
  "--identity-name", $identityName,
  "--publisher", $publisher,
  "--publisher-display-name", $publisherDisplayName,
  "--version", $version,
  "--output-path", $outputDirectory,
  "--output-name", $outputName,
  "--build-windows", "false",
  "--install-certificate", "false"
)

if ($Mode -eq "Store") {
  $arguments += "--store"
} else {
  $arguments += @("--certificate-path", $CertificatePath, "--certificate-password", $CertificatePassword)
}

& dart @arguments | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw "msix:create failed for $Mode mode."
}

Assert-MsixContents `
  -PackagePath $packagePath `
  -ExpectedIdentity $identityName `
  -ExpectedPublisher $publisher `
  -ExpectedVersion $version `
  -MustBeSigned ($Mode -eq "Sideload")

Write-Host "Validated $Mode package: $packagePath"
