# PowerShell script for checking generated data
# Usage: .\check-data.ps1

# Colors (compatible with PowerShell 5.1+)
if ($Host.UI.RawUI.SupportsVirtualTerminal) {
    $GREEN = "`e[32m"
    $YELLOW = "`e[33m"
    $RED = "`e[31m"
    $NC = "`e[0m"
} else {
    $GREEN = ""
    $YELLOW = ""
    $RED = ""
    $NC = ""
}

$dataDir = ".\data"

Write-Host "${GREEN}Checking generated data files...${NC}"

if (-not (Test-Path $dataDir)) {
    Write-Host "${RED}Error: Data directory does not exist${NC}"
    exit 1
}

Write-Host "${GREEN}Data files:${NC}"
$jsonlFiles = Get-ChildItem -Path $dataDir -Filter "*.jsonl" -ErrorAction SilentlyContinue
if ($jsonlFiles) {
    foreach ($file in $jsonlFiles) {
        $size = [math]::Round($file.Length / 1GB, 2)
        $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
        Write-Host "  $($file.Name): ${size} GB ($lines lines)"
    }
} else {
    Write-Host "${YELLOW}  No JSONL files found${NC}"
}

Write-Host ""
Write-Host "${GREEN}Reference files:${NC}"
$csvFiles = Get-ChildItem -Path $dataDir -Filter "*.csv" -ErrorAction SilentlyContinue
if ($csvFiles) {
    foreach ($file in $csvFiles) {
        $sizeKB = [math]::Round($file.Length / 1KB, 2)
        $lines = (Get-Content $file.FullName | Measure-Object -Line).Lines
        Write-Host "  $($file.Name): ${sizeKB} KB ($lines lines)"
    }
} else {
    Write-Host "${YELLOW}  No CSV files found${NC}"
}

Write-Host ""
Write-Host "${GREEN}Total size:${NC}"
$totalSize = (Get-ChildItem -Path $dataDir -File | Measure-Object -Property Length -Sum).Sum
$totalSizeGB = [math]::Round($totalSize / 1GB, 2)
Write-Host "  $totalSizeGB GB"

