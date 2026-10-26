# Single committed entry point for stack tasks (ADR-007).
.DEFAULT_GOAL := help
SHELL := /bin/bash

ENVS := dev prod
PROJECT_ROOTS := $(patsubst %/versions.tf,%,$(wildcard projects/*/versions.tf))
TF_ROOTS := environments/dev environments/prod modules/baseline $(PROJECT_ROOTS)
TEST_ROOTS := modules/baseline $(PROJECT_ROOTS)
TF_VERSION := 1.11.4

.PHONY: help
help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: init
init: ## Initialise every root and the module without a backend.
	@for dir in $(TF_ROOTS); do \
		echo "== init $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false -lockfile=readonly || exit 1; \
	done

.PHONY: fmt
fmt: ## Rewrite HCL to canonical format.
	terraform fmt -recursive .

.PHONY: fmt-check
fmt-check: ## Fail when HCL is not canonically formatted.
	terraform fmt -check -recursive .

.PHONY: validate
validate: ## Validate every root module and the baseline module.
	@for dir in $(TF_ROOTS); do \
		echo "== validate $$dir"; \
		terraform -chdir=$$dir validate || exit 1; \
	done

.PHONY: test
test: ## Run Terraform contract tests with mock providers.
	@for dir in $(TEST_ROOTS); do \
		echo "== test $$dir"; \
		terraform -chdir=$$dir test || exit 1; \
	done

.PHONY: scan
scan: ## Run Checkov with .checkov.yaml.
	checkov -d . --framework terraform --compact --quiet

.PHONY: verify
verify: ## Run every ADR and BDR verifier.
	bash verify/verify-all.sh

.PHONY: check
check: fmt-check validate test scan verify ## Run the full local gate.

.PHONY: evidence
evidence: ## Regenerate the evidence bundle under evidence/.
	bash evidence/generate.sh

.PHONY: prek-install
prek-install: ## Install prek hooks for this repository.
	prek install --prepare-hooks
	prek install --hook-type commit-msg

.PHONY: prek
prek: ## Run all prek hooks across the tree (CI mirror).
	prek run --all-files --show-diff-on-failure

.PHONY: clean
clean: ## Remove Terraform working directories (lockfiles are kept).
	find . -type d -name .terraform -prune -exec rm -rf {} +
