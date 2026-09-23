# Developer tasks. `make help` lists them; `make ci` is exactly what CI runs.
.DEFAULT_GOAL := help

.PHONY: help setup setup-all build release run install check ci lint fmt test doc deny clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Install/update the nightly toolchain, cargo-nextest, shellcheck
	./scripts/setup.sh

setup-all: ## setup + cargo-deny and actionlint
	./scripts/setup.sh --all

build: ## Debug build
	cargo build

release: ## Optimised build into target/release/
	cargo build --release --locked

run: ## Run the binary: make run ARGS="greet Ferris"
	cargo run -- $(ARGS)

install: ## cargo install into $CARGO_HOME/bin
	cargo install --path . --locked

check: lint test ## fmt --check + clippy + nextest + doctests (before every commit)

ci: ## Everything CI runs (scripts/ci.sh)
	./scripts/ci.sh

lint: ## fmt --check + strict clippy
	cargo fmt --check
	cargo clippy --all-targets --all-features -- -D warnings

fmt: ## Format the code
	cargo fmt

test: ## nextest + doctests
	cargo nextest run --all-features
	cargo test --doc --all-features

doc: ## Build the API docs (warnings are errors)
	RUSTDOCFLAGS="-D warnings" cargo doc --no-deps --all-features

deny: ## Supply-chain policy (deny.toml): advisories, licences, sources
	cargo deny --all-features --locked check

clean: ## Remove target/
	cargo clean
