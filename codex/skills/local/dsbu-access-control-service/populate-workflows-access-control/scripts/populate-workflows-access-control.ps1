param(
    [string] $WorkflowsRepo = "C:\work\dsbu-workflows",
    [string] $ContainerName = "access-control-service-database",
    [string] $Database = "local_dev_tenant_alias",
    [string] $PostgresUser = "postgres",
    [string] $InternalWorkflowsServiceUri = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

function Convert-EnumNameToLowerSpinal {
    param([Parameter(Mandatory = $true)][string] $Name)

    return $Name.ToLowerInvariant().Replace("_", "-")
}

function Read-RequiredFile {
    param([Parameter(Mandatory = $true)][string] $Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required file not found: $Path"
    }

    return Get-Content -LiteralPath $Path -Raw
}

function Convert-JavaStringLiteral {
    param([Parameter(Mandatory = $true)][string] $Value)

    return [regex]::Unescape($Value)
}

function Convert-SqlLiteral {
    param([Parameter(Mandatory = $true)][string] $Value)

    return $Value.Replace("'", "''")
}

$authorizationPath = Join-Path $WorkflowsRepo "common\src\main\java\com\thermofisher\workflows\common\authorization"
$applicationText = Read-RequiredFile (Join-Path $authorizationPath "Application.java")
$functionalityText = Read-RequiredFile (Join-Path $authorizationPath "Functionality.java")
$permissionText = Read-RequiredFile (Join-Path $authorizationPath "Permission.java")
$securityItemTypeText = Read-RequiredFile (Join-Path $authorizationPath "SecurityItemType.java")

$applicationMatch = [regex]::Match($applicationText, "(?m)^\s*([A-Z][A-Z0-9_]*)\s*;")
if (-not $applicationMatch.Success) {
    throw "Could not parse Workflows application enum."
}

$functionalityMatch = [regex]::Match($functionalityText, '(?m)^\s*([A-Z][A-Z0-9_]*)\("((?:[^"\\]|\\.)*)"\)\s*;')
if (-not $functionalityMatch.Success) {
    throw "Could not parse Workflows functionality enum."
}

$permissionMatches = [regex]::Matches($permissionText, '(?m)^\s*([A-Z][A-Z0-9_]*)\("((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)\s*[,;]')
if ($permissionMatches.Count -eq 0) {
    throw "Could not parse Workflows permission enum values."
}

$securityItemTypeMatches = [regex]::Matches($securityItemTypeText, '(?m)^\s*([A-Z][A-Z0-9_]*)\("((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)",\s*"((?:[^"\\]|\\.)*)"\)\s*[,;]')

$applicationName = Convert-EnumNameToLowerSpinal $applicationMatch.Groups[1].Value
$functionalityName = Convert-EnumNameToLowerSpinal $functionalityMatch.Groups[1].Value
$functionalityDisplayName = Convert-JavaStringLiteral $functionalityMatch.Groups[2].Value

$ordinal = 0
$permissions = foreach ($match in $permissionMatches) {
    [pscustomobject] @{
        name = Convert-EnumNameToLowerSpinal $match.Groups[1].Value
        display_name = Convert-JavaStringLiteral $match.Groups[2].Value
        description = Convert-JavaStringLiteral $match.Groups[3].Value
        ordinal = $ordinal++
    }
}

$securityItemOrdinal = 0
$securityItemTypes = foreach ($match in $securityItemTypeMatches) {
    $allFetchPath = Convert-JavaStringLiteral $match.Groups[3].Value
    $singleFetchPath = Convert-JavaStringLiteral $match.Groups[4].Value

    [pscustomobject] @{
        name = Convert-EnumNameToLowerSpinal $match.Groups[1].Value
        display_name = Convert-JavaStringLiteral $match.Groups[2].Value
        all_fetch_uri = $InternalWorkflowsServiceUri.TrimEnd("/") + $allFetchPath
        single_fetch_uri = $InternalWorkflowsServiceUri.TrimEnd("/") + $singleFetchPath
        ordinal = $securityItemOrdinal++
    }
}

$permissionArray = [object[]] $permissions
$securityItemTypeArray = [object[]] $securityItemTypes

$functionalityObjectPayload = [pscustomobject] @{
    name = $functionalityName
    display_name = $functionalityDisplayName
    permissions = $permissionArray
    security_item_types = $securityItemTypeArray
} | ConvertTo-Json -Depth 8 -Compress

$functionalityPayload = "[$functionalityObjectPayload]"

$sqlPayload = Convert-SqlLiteral $functionalityPayload
$sqlApplicationName = Convert-SqlLiteral $applicationName

$sql = @"
INSERT INTO sd_access_control_service.application (name)
SELECT '$sqlApplicationName'
WHERE NOT EXISTS (
    SELECT 1
    FROM sd_access_control_service.application
    WHERE LOWER(name) = LOWER('$sqlApplicationName')
);

DO
`$`$
DECLARE
    v_error_message TEXT;
    v_exit_code TEXT;
BEGIN
    SELECT
        o_error_message,
        o_exit_code
    INTO
        v_error_message,
        v_exit_code
    FROM
        sd_access_control_service.replace_functionality_v2_fn(
            p_application_name => '$sqlApplicationName',
            p_functionality_data => '$sqlPayload'::jsonb
        );

    IF v_exit_code IS DISTINCT FROM '00000'
    THEN
        RAISE EXCEPTION 'replace_functionality_v2_fn failed: % %', v_exit_code, v_error_message;
    END IF;
END;
`$`$;

SELECT
    p.ordinal,
    p.code_name,
    p.display_name,
    p.description,
    p.obsolete
FROM
    sd_access_control_service.permission p
JOIN
    sd_access_control_service.functionality f ON f.id = p.functionality_id_fk
JOIN
    sd_access_control_service.application a ON a.id = f.application_id_fk
WHERE
    LOWER(a.name) = LOWER('$sqlApplicationName')
    AND f.code_name = '$functionalityName'
ORDER BY
    p.ordinal,
    p.id;
"@

$containerExists = docker ps --filter "name=^/$ContainerName$" --format "{{.Names}}"
if ($containerExists -ne $ContainerName) {
    throw "Docker container is not running: $ContainerName"
}

Write-Host "Seeding $($permissions.Count) Workflows permissions into $Database on $ContainerName..."
$sql | docker exec -i $ContainerName psql -U $PostgresUser -d $Database -v ON_ERROR_STOP=1
