# PowerShell script for cleaning generated data
# Usage: .\clean-data.ps1

# Colors (compatible with PowerShell 5.1+)
if ($Host.UI.RawUI.SupportsVirtualTerminal) {
    $GREEN = "`e[32m"
    $YELLOW = "`e[33m"
    $NC = "`e[0m"
} else {
    $GREEN = ""
    $YELLOW = ""
    $NC = ""
}

$dataDir = ".\data"

Write-Host "${YELLOW}Removing generated data files...${NC}"

if (Test-Path $dataDir) {
    Remove-Item -Path "$dataDir\*.jsonl" -ErrorAction SilentlyContinue
    Remove-Item -Path "$dataDir\*.csv" -ErrorAction SilentlyContinue
    Write-Host "${GREEN}[OK] Cleanup completed${NC}"
} else {
    Write-Host "${YELLOW}Data directory does not exist${NC}"
}

