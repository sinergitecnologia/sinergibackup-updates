param(
    [string]$ManifestPath = ".\channels\stable.json"
)

$ErrorActionPreference = "Stop"

function Fail {
    param([string]$Message)

    Write-Host "[FALHA] $Message"
    exit 1
}

function Pass {
    param([string]$Message)

    Write-Host "[OK] $Message"
}

Write-Host ""
Write-Host "============================================================"
Write-Host " SINERGI BACKUP - VALIDACAO DO MANIFESTO STABLE"
Write-Host "============================================================"
Write-Host ""

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Fail "Manifesto nao encontrado: $ManifestPath"
}

try {
    $raw = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
    $manifest = $raw | ConvertFrom-Json
}
catch {
    Fail "JSON invalido: $($_.Exception.Message)"
}

Pass "JSON valido."

# ------------------------------------------------------------
# Campos obrigatorios
# ------------------------------------------------------------

$requiredProperties = @(
    "channel",
    "latestVersion",
    "minimumSupportedVersion",
    "publishedAt",
    "downloadUrl",
    "sha256",
    "sizeBytes",
    "releaseNotesUrl",
    "releaseNotes",
    "mandatory"
)

$propertyNames = @($manifest.PSObject.Properties.Name)

foreach ($property in $requiredProperties) {
    if ($propertyNames -notcontains $property) {
        Fail "Campo obrigatorio ausente: $property"
    }
}

Pass "Todos os campos obrigatorios existem."

# ------------------------------------------------------------
# Canal
# ------------------------------------------------------------

if ($manifest.channel -isnot [string] -or $manifest.channel -cne "stable") {
    Fail "channel deve ser exatamente 'stable'."
}

Pass "channel = stable."

# ------------------------------------------------------------
# Versoes
# Compatibilidade atual: clientes 0.2.x usam este contrato.
# ------------------------------------------------------------

$semVerPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$'

if (
    $manifest.latestVersion -isnot [string] -or
    $manifest.latestVersion -notmatch $semVerPattern
) {
    Fail "latestVersion nao possui formato SemVer valido."
}

Pass "latestVersion valido: $($manifest.latestVersion)"

if (
    $manifest.minimumSupportedVersion -isnot [string] -or
    $manifest.minimumSupportedVersion -notmatch $semVerPattern
) {
    Fail "minimumSupportedVersion nao possui formato SemVer valido."
}

Pass "minimumSupportedVersion valido: $($manifest.minimumSupportedVersion)"

# ------------------------------------------------------------
# Data de publicacao
# ------------------------------------------------------------

$publishedAtText = if ($manifest.publishedAt -is [DateTime]) {
    $manifest.publishedAt.ToUniversalTime().ToString(
        "o",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}
elseif ($manifest.publishedAt -is [DateTimeOffset]) {
    $manifest.publishedAt.ToUniversalTime().ToString(
        "o",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}
elseif ($manifest.publishedAt -is [string]) {
    $manifest.publishedAt
}
else {
    Fail "publishedAt deve representar uma data/hora valida."
}

$publishedDate = [DateTimeOffset]::MinValue

if (-not [DateTimeOffset]::TryParse(
    $publishedAtText,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::RoundtripKind,
    [ref]$publishedDate
)) {
    Fail "publishedAt nao possui data/hora valida."
}

Pass "publishedAt valido."

# ------------------------------------------------------------
# URLs
# ------------------------------------------------------------

foreach ($urlProperty in @("downloadUrl", "releaseNotesUrl")) {

    $value = $manifest.$urlProperty

    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        Fail "$urlProperty deve ser string nao vazia."
    }

    $uri = $null

    if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri)) {
        Fail "$urlProperty nao e uma URL absoluta valida."
    }

    if ($uri.Scheme -cne "https") {
        Fail "$urlProperty deve utilizar HTTPS."
    }

    if ($uri.Host -cne "github.com") {
        Fail "$urlProperty deve apontar para github.com."
    }

    Pass "$urlProperty valido."
}

# ------------------------------------------------------------
# SHA-256
# ------------------------------------------------------------

if (
    $manifest.sha256 -isnot [string] -or
    $manifest.sha256 -notmatch '^[A-Fa-f0-9]{64}$'
) {
    Fail "sha256 deve conter exatamente 64 caracteres hexadecimais."
}

Pass "SHA256 valido."

# ------------------------------------------------------------
# Tamanho
# ------------------------------------------------------------

if (
    $manifest.sizeBytes -isnot [long] -and
    $manifest.sizeBytes -isnot [int]
) {
    Fail "sizeBytes deve ser inteiro."
}

if ([long]$manifest.sizeBytes -le 0) {
    Fail "sizeBytes deve ser maior que zero."
}

Pass "sizeBytes valido: $($manifest.sizeBytes)"

# ------------------------------------------------------------
# releaseNotes
#
# REGRA DE COMPATIBILIDADE:
# clientes Sinergi Backup 0.2.x desserializam ReleaseNotes
# como System.String.
#
# NAO alterar para array enquanto esses clientes forem
# suportados pelo canal stable.
# ------------------------------------------------------------

if ($manifest.releaseNotes -isnot [string]) {
    Fail "releaseNotes DEVE permanecer System.String para compatibilidade com clientes 0.2.x."
}

if ([string]::IsNullOrWhiteSpace($manifest.releaseNotes)) {
    Fail "releaseNotes nao pode ser vazio."
}

Pass "releaseNotes = System.String (contrato legado preservado)."

# ------------------------------------------------------------
# mandatory
# ------------------------------------------------------------

if ($manifest.mandatory -isnot [bool]) {
    Fail "mandatory deve ser boolean."
}

Pass "mandatory valido: $($manifest.mandatory)"

Write-Host ""
Write-Host "============================================================"
Write-Host " MANIFESTO STABLE APROVADO"
Write-Host "============================================================"
Write-Host ""

exit 0