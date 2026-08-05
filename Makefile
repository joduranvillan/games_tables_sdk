.PHONY: test test-stress build-godot test-godot android-aar docs install-hooks

test:
	cargo test --workspace

test-stress:
	cargo test --workspace -- --ignored

build-godot:
	cargo build -p open_table_godot

test-godot:
	./tools/run_godot_tests.sh

android-aar:
	cd platform_plugins && ./gradlew assembleRelease

docs:
	cargo doc --no-deps --workspace --document-private-items

install-hooks:
	mkdir -p .git/hooks
	cp tools/hooks/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Git pre-commit hook installed in .git/hooks/pre-commit"
