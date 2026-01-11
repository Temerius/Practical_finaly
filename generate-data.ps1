# PowerShell script for generating data files
# Usage: .\generate-data.ps1 [-Size <GB>] [-Count <number>] [-Small]

param(
    [int]$Size = 16,
    [int]$Count = 2,
    [switch]$Small = $false
)

# Colors (compatible with PowerShell 5.1+)
if ($Host.UI.RawUI.SupportsVirtualTerminal) {
    $GREEN = "`e[32m"
    $BLUE = "`e[34m"
    $YELLOW = "`e[33m"
    $RED = "`e[31m"
    $NC = "`e[0m"
} else {
    $GREEN = ""
    $BLUE = ""
    $YELLOW = ""
    $RED = ""
    $NC = ""
}

# Set size to 1GB for small option
if ($Small) {
    $Size = 1
    Write-Host "${BLUE}Generating small test files (1GB each)...${NC}"
} else {
    Write-Host "${BLUE}Generating data files: ${Size}GB per file, ${Count} files...${NC}"
    Write-Host "${YELLOW}This will take a while (generating files >16GB)...${NC}"
}

# Create data directory
$dataDir = Join-Path (Get-Location).Path "data"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
    Write-Host "${GREEN}Created data directory${NC}"
}

# Set environment variables
$env:DATA_FILE_SIZE_GB = $Size
$env:NUM_LARGE_FILES = $Count
$env:DATA_OUTPUT_DIR = $dataDir
$env:CORRUPTION_RATE = "0.001"
$env:MISSING_DATA_RATE = "0.05"
$env:DUPLICATE_RATE = "0.02"
$env:OUTLIER_RATE = "0.01"

# Check if Docker is available
$dockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
$dockerComposeAvailable = $null -ne (Get-Command docker-compose -ErrorAction SilentlyContinue)

if ($dockerAvailable -and $dockerComposeAvailable) {
    Write-Host "${GREEN}Using Docker for data generation...${NC}"
    
    # Build Docker image
    Write-Host "${BLUE}Building Docker image...${NC}"
    docker-compose build data-generator
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}Error building Docker image${NC}"
        exit 1
    }
    
    # Run generator
    Write-Host "${BLUE}Running data generator...${NC}"
    docker-compose run --rm data-generator
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}Error running data generator${NC}"
        exit 1
    }
    
    Write-Host "${GREEN}[OK] Data generation completed${NC}"
    Write-Host "${YELLOW}Check $dataDir directory for generated files${NC}"
} else {
    Write-Host "${YELLOW}Docker not available, trying local generation...${NC}"
    
    # Check if Python is available
    $pythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
    if (-not $pythonAvailable) {
        Write-Host "${RED}Error: Neither Docker nor Python is available${NC}"
        Write-Host "${YELLOW}Please install Docker or Python to generate data${NC}"
        exit 1
    }
    
    # Install dependencies
    Write-Host "${BLUE}Installing Python dependencies...${NC}"
    Set-Location data_generator
    python -m pip install -r requirements.txt --quiet
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}Error installing dependencies${NC}"
        exit 1
    }
    
    # Run generator
    Write-Host "${BLUE}Running data generator...${NC}"
    python generate_data.py
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "${RED}Error running data generator${NC}"
        exit 1
    }
    
    Set-Location ..
    Write-Host "${GREEN}[OK] Local data generation completed${NC}"
    Write-Host "${YELLOW}Check $dataDir directory for generated files${NC}"
}

