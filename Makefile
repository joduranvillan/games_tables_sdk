.PHONY: test test-stress build-godot build-android test-godot android-aar docs metrics install-hooks publish-dry-run audit

PUBLISH_CRATES = open_table_macros open_table_core open_table_engine checkers_game battleship_game ludo_game mille_bornes_game backgammon_game chinese_checkers_game monopoly_game chess_game shogi_game xiangqi_game go_game uno_game crisis_game open_table_transport_tcp open_table_transport_websocket open_table_qr

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

publish-dry-run:
	@for crate in $(PUBLISH_CRATES); do \
		echo "==> Dry-run publish: $$crate"; \
		cargo publish --dry-run --allow-dirty -p $$crate || exit 1; \
	done

audit:
	cargo deny check
	@if command -v cargo-audit >/dev/null 2>&1; then \
		cargo audit; \
	else \
		echo "cargo-audit not installed, skipping cargo audit"; \
	fi

install-hooks:
	mkdir -p .git/hooks
	cp tools/hooks/pre-commit .git/hooks/pre-commit
	chmod +x .git/hooks/pre-commit
	@echo "Git pre-commit hook installed in .git/hooks/pre-commit"
