# PowerShell script for validating data structure
# Usage: .\validate-data.ps1

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
$firstFile = "$dataDir\events_large_1.jsonl"

Write-Host "${GREEN}Validating data structure...${NC}"

if (-not (Test-Path $firstFile)) {
    Write-Host "${RED}Error: No data files found. Run '.\generate-data.ps1' first${NC}"
    exit 1
}

Write-Host "${GREEN}Checking first 100 lines of events_large_1.jsonl...${NC}"

$validCount = 0
$invalidCount = 0
$lines = Get-Content $firstFile -Head 100

foreach ($line in $lines) {
    try {
        $json = $line | ConvertFrom-Json -ErrorAction Stop
        $validCount++
    } catch {
        $invalidCount++
    }
}

Write-Host "${GREEN}Valid JSON lines: $validCount${NC}"
if ($invalidCount -gt 0) {
    Write-Host "${YELLOW}[!] Invalid/corrupted JSON lines: $invalidCount (this is expected)${NC}"
} else {
    Write-Host "${GREEN}[OK] All checked lines are valid JSON${NC}"
}

