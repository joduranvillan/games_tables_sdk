.PHONY: test test-stress build-godot build-android test-godot android-aar docs metrics install-hooks

test:
	cargo test --workspace

test-stress:
	cargo test --workspace -- --ignored

build-godot:
	cargo build -p open_table_godot

build-android:
	cargo build --target aarch64-linux-android --release -p open_table_godot

test-godot:
	./tools/run_godot_tests.sh

android-aar:
	cd platform_plugins && ./gradlew assembleRelease

docs:
	cargo doc --no-deps --workspace --document-private-items

metrics:
	./tools/metrics.sh

install-hooks:
	mkdir -p .git/hooks
	cp tools/hooks/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Git pre-commit hook installed in .git/hooks/pre-commit"
