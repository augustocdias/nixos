---
name: rust-best-practices
description: "Use when reading or editing .rs files."
---

[Shared workflow](WORKFLOW.md)

# Rust best practices

Make the compiler reject impossible states, mismatched primitives and unhandled variants. Untrusted input becomes a domain type once, where it enters; code inside trusts the type. Follow the repository's existing error type, lint configuration and test style where they already decide a row below.

| Rule | Summary |
|------|---------|
| Enums for variants | Model mutually exclusive states as an `enum` with data in its variants, not `bool` flags plus `Option` fields. |
| Newtypes | Wrap IDs, units and validated strings in a tuple struct with a private field so they can't be mixed up. |
| Fallible construction | A newtype with an invariant gets a `Result` constructor and `TryFrom`/`FromStr`. It offers no infallible `From` and no `pub` field. |
| Simplest total type | Use a stronger std type (`PathBuf`, `NonZero`, `Duration`) where the weaker one forces a check. Keep plain numbers in public numeric APIs. |
| Parse at the boundary | Convert CLI args, config, env, network payloads and database rows into domain types where they enter. |
| Serde does the parse | Derive `Deserialize` on the domain type. Use `#[serde(try_from = "Raw")]` for invariants and `#[serde(deny_unknown_fields)]` on strict input. Keep `serde_json::Value` at the boundary. |
| Exhaustive match | Match every variant of your own enums so a new variant is a compile error. Lints: `wildcard_enum_match_arm`, `match_wildcard_for_single_variants`. |
| `#[non_exhaustive]` | Use it only on public library types meant to grow. Inside the defining crate it has no effect. |
| Checked numeric conversion | Use `From` for widening, `TryFrom` for narrowing, and `checked_*`/`saturating_*`/`wrapping_*` for arithmetic that can overflow, since release builds wrap silently. `as` stays for float and integer conversions, where std has no `TryFrom`; comment the range it relies on. |
| Typed errors in libraries | Libraries return typed errors (a `thiserror` enum or an error struct, matching the crate's existing style). Binaries may use `anyhow` or `eyre` with context. Convert with `From` and `?`. |
| `?` over `unwrap` | Use `?` for expected failure, `expect("why this cannot fail")` for a proven invariant, and `unwrap` in tests. Projects that want enforcement opt into `unwrap_used` and `expect_used` with `allow-unwrap-in-tests`. |
| Panic means bug | Panic on a broken contract. Return `Result` for anything a caller or input can cause. Ship no `todo!` or `unimplemented!`. |
| `.get()` on untrusted indexes | Use `.get()`, iterators or slice patterns where an index or range comes from input. Lints: `indexing_slicing`, `string_slice`. |
| Borrow before cloning | Fix ownership first (borrow, take `&str` or `&[T]`, move) and add `.clone()` only when the value truly needs two owners. |
| Lints, then `#[expect]` | Run `cargo clippy --all-targets -- -D warnings`. Silence a single site with `#[expect(lint, reason = "...")]`. Enable restriction lints one at a time, never the whole group. |
| `unsafe` with a reason | Use `unsafe` only for FFI, a new safe abstraction, or a benchmarked hot path. Each block gets a `// SAFETY:` comment and a Miri run. |
| Real tests | Assert behavior and properties against independent expected values. Put I/O behind an injectable seam, and test against the real thing (temp dirs, a local service) when it runs locally. |
| Structured telemetry | Use `tracing` or another structured logger in shipped code. Lints: `print_stdout`, `dbg_macro`. |

Examples: [patterns](references/patterns.md).

Sources: Microsoft Pragmatic Rust Guidelines (MIT, https://microsoft.github.io/rust-guidelines), Rust API Guidelines (https://rust-lang.github.io/api-guidelines), Clippy lint documentation, the Rust Book chapters 3.2 and 9.3, the Rust Reference on `non_exhaustive`, and the serde container attribute docs.
