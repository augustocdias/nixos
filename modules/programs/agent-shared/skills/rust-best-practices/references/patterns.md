# Rust patterns

Code examples for rules in `SKILL.md`.

## Enums for variants

```rust
// Bad: two fields that must stay in sync.
struct Job { running: bool, exit_code: Option<i32> }

// Good: each state carries only its own data.
enum Job {
    Queued,
    Running { pid: u32 },
    Finished { exit_code: i32 },
}
```

## Newtype with fallible construction

```rust
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Email(String);

#[derive(Debug, thiserror::Error)]
#[error("invalid email: {0}")]
pub struct InvalidEmail(String);

impl TryFrom<String> for Email {
    type Error = InvalidEmail;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        if value.contains('@') {
            Ok(Self(value))
        } else {
            Err(InvalidEmail(value))
        }
    }
}

impl Email {
    pub fn as_str(&self) -> &str {
        &self.0
    }
}
```

The field is private, so the only way to get an `Email` is through the check.

## Exhaustive match

```rust
fn label(job: &Job) -> &'static str {
    match job {
        Job::Queued => "queued",
        Job::Running { .. } => "running",
        Job::Finished { .. } => "finished",
        // No `_ =>` arm: adding a variant fails to compile here.
    }
}
```

## Serde does the parse

```rust
#[derive(serde::Deserialize)]
#[serde(deny_unknown_fields)]
struct RawConfig {
    port: u32,
}

#[derive(Debug, serde::Deserialize)]
#[serde(try_from = "RawConfig")]
pub struct Config {
    port: u16,
}

impl TryFrom<RawConfig> for Config {
    type Error = std::num::TryFromIntError;

    fn try_from(raw: RawConfig) -> Result<Self, Self::Error> {
        Ok(Self { port: u16::try_from(raw.port)? })
    }
}
```

`serde_json::from_str::<Config>(input)` now rejects unknown fields and out-of-range ports at the boundary. With `try_from`, serde reads the input as `RawConfig`, so the wire-shape attributes such as `deny_unknown_fields` go on the raw struct.

## Checked numeric conversion

```rust
// Bad: silently truncates values above 65535.
let port = raw as u16;

// Good: the failure is a value the caller handles.
let port = u16::try_from(raw)?;
let total = a.checked_add(b).ok_or(Error::Overflow)?;
```

## Typed errors in a library, context in a binary

```rust
// Library crate.
#[derive(Debug, thiserror::Error)]
pub enum LoadError {
    #[error("config file not found: {0}")]
    NotFound(std::path::PathBuf),
    #[error("config is invalid")]
    Invalid(#[from] serde_json::Error),
}

// Binary crate.
fn main() -> anyhow::Result<()> {
    use anyhow::Context;
    let config = mylib::load(&path).with_context(|| format!("loading {}", path.display()))?;
    run(config)
}
```

## `expect` for a proven invariant

```rust
// The regex is a literal checked by tests, so failure is a bug.
let re = regex::Regex::new(r"^\d+$").expect("literal regex is valid");
```

## `#[expect]` with a reason

```rust
#[expect(clippy::cast_possible_truncation, reason = "value is bounded to 0..=255 above")]
let byte = value as u8;
```

`#[expect]` warns when the lint stops firing, so stale suppressions surface on their own.

## `.get()` on untrusted indexes

```rust
// Bad: panics on a short input.
let first = parts[0];

// Good.
let first = parts.first().ok_or(Error::Empty)?;
```
