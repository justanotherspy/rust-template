# Developer tasks. `make help` lists them; `make ci` is exactly what CI runs.
.DEFAULT_GOAL := help

.PHONY: help setup setup-all hooks build release run install check ci lint fmt test doc deny shear bench outdated watch watch-run clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Install/update the nightly toolchain, cargo-nextest, shellcheck
	./scripts/setup.sh

setup-all: ## setup + cargo-deny, actionlint, cargo-shear, bacon, watchexec
	./scripts/setup.sh --all

hooks: ## Run fmt --check + clippy before every commit (.githooks/pre-commit)
	git config core.hooksPath .githooks

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

shear: ## Find dependencies Cargo.toml declares but the code never uses
	cargo shear

bench: ## criterion benchmarks (benches/): make bench ARGS="--save-baseline main"
	cargo bench --bench '*' -- $(ARGS)

outdated: ## Dependencies with newer versions (what `cargo update` would change)
	cargo update --dry-run --verbose

watch: ## bacon: re-run strict clippy on every save (t tests, r run, ? keys)
	bacon

watch-run: ## watchexec: clippy, then tests, then run, on every save
	watchexec --clear --exts rs,toml -- 'cargo clippy --all-targets --all-features -- -D warnings && cargo nextest run --all-features && cargo run -- $(ARGS)'

clean: ## Remove target/
	cargo clean
