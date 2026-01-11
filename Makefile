.PHONY: help generate-data generate-data-small clean setup

# Default target
.DEFAULT_GOAL := help

# Variables
DOCKER_COMPOSE := docker-compose
PYTHON := python3
DATA_DIR := ./data

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Data Generator - Makefile Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-25s$(NC) %s\n", $$1, $$2}'

setup: ## Initial setup: create data directory
	@echo "$(GREEN)Creating data directory...$(NC)"
	@mkdir -p $(DATA_DIR)
	@echo "$(GREEN)✓ Setup completed$(NC)"

generate-data: setup ## Generate large data files (default: 16GB per file, 2 files)
	@echo "$(BLUE)Generating data files...$(NC)"
	@echo "$(YELLOW)This will take a while (generating files >16GB)...$(NC)"
	@$(DOCKER_COMPOSE) build data-generator
	@$(DOCKER_COMPOSE) run --rm data-generator
	@echo "$(GREEN)✓ Data generation completed$(NC)"
	@echo "$(YELLOW)Check $(DATA_DIR) directory for generated files$(NC)"

generate-data-small: setup ## Generate small test files (1GB per file, 2 files) - for quick testing
	@echo "$(BLUE)Generating small test files (1GB each)...$(NC)"
	@DATA_FILE_SIZE_GB=1 NUM_LARGE_FILES=2 $(DOCKER_COMPOSE) build data-generator
	@DATA_FILE_SIZE_GB=1 NUM_LARGE_FILES=2 $(DOCKER_COMPOSE) run --rm data-generator
	@echo "$(GREEN)✓ Test data generation completed$(NC)"

generate-data-custom: setup ## Generate custom size files (usage: make generate-data-custom SIZE=40GB COUNT=3)
	@if [ -z "$(SIZE)" ] || [ -z "$(COUNT)" ]; then \
		echo "$(RED)Error: SIZE and COUNT must be set$(NC)"; \
		echo "Usage: make generate-data-custom SIZE=40GB COUNT=3"; \
		echo "Note: Remove 'GB' suffix, just use number: SIZE=40"; \
		exit 1; \
	fi
	@echo "$(BLUE)Generating custom files: $(SIZE) GB per file, $(COUNT) files...$(NC)"
	@DATA_FILE_SIZE_GB=$(SIZE) NUM_LARGE_FILES=$(COUNT) $(DOCKER_COMPOSE) build data-generator
	@DATA_FILE_SIZE_GB=$(SIZE) NUM_LARGE_FILES=$(COUNT) $(DOCKER_COMPOSE) run --rm data-generator
	@echo "$(GREEN)✓ Custom data generation completed$(NC)"

generate-local: setup ## Generate data locally (without Docker) - faster for testing
	@echo "$(BLUE)Generating data locally...$(NC)"
	@cd data_generator && $(PYTHON) -m pip install -r requirements.txt --quiet
	@cd data_generator && DATA_OUTPUT_DIR=../$(DATA_DIR) $(PYTHON) generate_data.py
	@echo "$(GREEN)✓ Local data generation completed$(NC)"

generate-local-small: setup ## Generate small test files locally (1GB each)
	@echo "$(BLUE)Generating small test files locally (1GB each)...$(NC)"
	@cd data_generator && $(PYTHON) -m pip install -r requirements.txt --quiet
	@cd data_generator && DATA_FILE_SIZE_GB=1 NUM_LARGE_FILES=2 DATA_OUTPUT_DIR=../$(DATA_DIR) $(PYTHON) generate_data.py
	@echo "$(GREEN)✓ Local test data generation completed$(NC)"

clean: ## Remove generated data files
	@echo "$(YELLOW)Removing generated data files...$(NC)"
	@rm -rf $(DATA_DIR)/*.jsonl
	@rm -rf $(DATA_DIR)/*.csv
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

clean-all: clean ## Remove all generated files and Docker volumes
	@echo "$(YELLOW)Removing Docker volumes...$(NC)"
	@$(DOCKER_COMPOSE) down -v
	@echo "$(GREEN)✓ Full cleanup completed$(NC)"

check-data: ## Check generated data files
	@echo "$(BLUE)Checking generated data files...$(NC)"
	@if [ ! -d "$(DATA_DIR)" ]; then \
		echo "$(RED)Error: Data directory does not exist$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Data files:$(NC)"
	@ls -lh $(DATA_DIR)/*.jsonl 2>/dev/null || echo "$(YELLOW)No JSONL files found$(NC)"
	@echo ""
	@echo "$(GREEN)Reference files:$(NC)"
	@ls -lh $(DATA_DIR)/*.csv 2>/dev/null || echo "$(YELLOW)No CSV files found$(NC)"
	@echo ""
	@echo "$(GREEN)Total size:$(NC)"
	@du -sh $(DATA_DIR) 2>/dev/null || echo "$(YELLOW)Cannot calculate size$(NC)"

validate-data: ## Validate data file structure (checks first 100 lines)
	@echo "$(BLUE)Validating data structure...$(NC)"
	@if [ ! -f "$(DATA_DIR)/events_large_1.jsonl" ]; then \
		echo "$(RED)Error: No data files found. Run 'make generate-data' first$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Checking first 100 lines of events_large_1.jsonl...$(NC)"
	@head -n 100 $(DATA_DIR)/events_large_1.jsonl | python3 -m json.tool > /dev/null 2>&1 && \
		echo "$(GREEN)✓ Valid JSON structure (first 100 lines)$(NC)" || \
		echo "$(YELLOW)⚠ Some lines may be corrupted (this is expected)$(NC)"

stats: ## Show statistics about generated data
	@echo "$(BLUE)Data Statistics$(NC)"
	@echo "$(GREEN)Large files:$(NC)"
	@for file in $(DATA_DIR)/events_large_*.jsonl; do \
		if [ -f "$$file" ]; then \
			size=$$(du -h "$$file" | cut -f1); \
			lines=$$(wc -l < "$$file" 2>/dev/null || echo "0"); \
			echo "  $$(basename $$file): $$size ($$lines lines)"; \
		fi \
	done
	@echo "$(GREEN)Reference files:$(NC)"
	@for file in $(DATA_DIR)/*.csv; do \
		if [ -f "$$file" ]; then \
			size=$$(du -h "$$file" | cut -f1); \
			lines=$$(wc -l < "$$file" 2>/dev/null || echo "0"); \
			echo "  $$(basename $$file): $$size ($$lines lines)"; \
		fi \
	done

