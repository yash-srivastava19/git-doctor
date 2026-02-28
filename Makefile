.PHONY: install test lint help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install: ## Install git-doctor to ~/.git-doctor and symlink to ~/.local/bin
	bash install.sh

test: ## Run the full test suite (requires bats-core)
	@command -v bats >/dev/null 2>&1 || { \
		echo "bats-core not found."; \
		echo "  Linux:  git clone https://github.com/bats-core/bats-core /tmp/bats && sudo /tmp/bats/install.sh /usr/local"; \
		echo "  macOS:  brew install bats-core"; \
		exit 1; \
	}
	bats tests/unit/ tests/integration/

test-unit: ## Run unit tests only
	bats tests/unit/

test-integration: ## Run integration tests only
	bats tests/integration/

lint: ## Run ShellCheck (requires shellcheck)
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "shellcheck not found."; \
		echo "  Linux:  sudo apt install shellcheck"; \
		echo "  macOS:  brew install shellcheck"; \
		exit 1; \
	}
	shellcheck -S warning bin/git-doctor lib/colors.sh lib/checks.sh lib/organize.sh install.sh
