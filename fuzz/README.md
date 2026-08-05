# Fuzz Testing for OpenTable SDK (Crisis / TEG)

This directory contains fuzz targets for the `crisis_game` crate using `cargo-fuzz` and `libfuzzer-sys`.

## Running Fuzzers

To run the `fuzz_crisis` target:

```bash
cargo fuzz run fuzz_crisis
```

This target deserializes arbitrary raw bytes as a `DeclareAttackCommand` and processes it within a valid TEG session, ensuring the game engine never panics when handling malformed or hostile inputs.
