# Recordings

Each file here is one test case's conversation with a real container,
recorded by [Servirtium](https://servirtium.dev) standing between the test
and the container: every request the test made, in order, and the response
the service gave. The markdown renders on GitHub and diffs in a review.

```
recordings/<test file stem>/<case>.md
recordings/test_vault/reads_and_writes_secrets_with_the_chosen_token.md
```

`<case>` is the snake_case name the test passes to
`servirtium.recording(...)`, near the spec `it` title.

| Suite | Cases | Container |
|---|---|---|
| `test_vault` | 2 | `hashicorp/vault:1.13.0` |
| `test_couchdb` | 3 | `couchdb:3` |
| `test_consul` | 4 | `hashicorp/consul:1.15` |
| `test_openfga` | 1 | `openfga/openfga:v1.18.0` |
| `test_typesense` | 3 | `typesense/typesense:26.0` |
| `test_mockserver` | 2 | `mockserver/mockserver:5.15.0` |

## A tape is a test scenario you can keep

A project that has these tapes can drop the container: with
`TCAE_VCR=playback` each case's HTTP checks run against a Servirtium replay
server inside the test process, answering from the tape, with no engine and
no image. The replay is strict: a request that differs from the recorded
one (method, path, recorded headers, body) or a recorded request that is
never made fails the case. The same tapes replay under any Servirtium
implementation (Java, Go, Python, ... and `servirtium serve <tape.md>` from
servirtium-vcr's CLI), so they also serve as a stand-in for the service in
other test suites.

What a tape cannot replay is what never went over HTTP: `tc.exec`,
inspecting the container, a case that is about the container failing to
start. Those checks sit in the `if servirtium.live() == 1 { ... }` part of
the case or in a case gated by `spec.it_when(servirtium.live(), ...)`, and
are skipped in playback.

## Modes (`TCAE_VCR`)

```sh
ae test tests/test_vault.ae                         # off (default): container, no Servirtium
TCAE_VCR=record   ae test tests/test_vault.ae       # container, Servirtium in the middle, tapes written
TCAE_VCR=check    ae test tests/test_vault.ae       # record, and fail if a tape changed (<case>.md.actual left beside it)
TCAE_VCR=playback ae test tests/test_vault.ae       # no container, no engine: replay the tapes
```

`TCAE_VCR_DIR` puts the tapes somewhere other than `recordings/`.

To re-record after changing a test or bumping an image: run it with
`TCAE_VCR=record` and review `git diff recordings/`. Recording twice in a
row writes the same bytes (the normalizations below make it so), so a diff
is a real change in the service or in the test. `TCAE_VCR=check` is that
comparison as a failing test, for CI.

## What the requests carry

Go's module tests talk raw HTTP through `net/http`, which sends
`User-Agent: Go-http-client/1.1` by itself; Aether's `std.http.client` sends
no `User-Agent` at all. Each test's request helper sets one
(`USER_AGENT`, `testcontainers-ae-tests (Aether std.http.client)`), as an
app's client library would, so the recordings show a representative request.
That is the test's client speaking: Servirtium records the headers as they
were sent and adds none.

## Normalizations in force

Each recording ends with a `## [Recording rules]` table that lists the rules
below as they applied to it: what was left out or rewritten, and in which
interactions (`none` for a rule that matched nothing there). A redaction's
secret is never shown, only its placeholder. Playback does not read that
section.

Applied when a tape is written; playback serves the tape as written.

Always (`testcontainers/servirtium/module.ae`):

- the `Date`, `X-Request-Id` and `X-Correlation-Id` response headers are
  left out;
- the container's mapped `host:port` and the recorder's own `127.0.0.1:port`
  become `{{request.host}}` (CouchDB's `Location` headers, for one), which
  playback fills with the replay server's own host and port.

Per suite (registered at the top of its `main`):

| Suite | Normalized (stable `{{name-N}}` tokens) | Collapsed to a constant | Redacted (put back on playback) | Headers dropped |
|---|---|---|---|---|
| vault | UUIDs (request and cluster ids) | `vault-cluster-<hex>`, RFC 3339 times, Unix times | the root token in `X-Vault-Token` | |
| couchdb | the 32-hex server uuid | Unix start times, `*_seq` tokens | each `Authorization: Basic` credential, as `REDACTED[<label>]` | `X-Couch-Request-ID`, `X-CouchDB-Body-Time` |
| consul | the node id | Raft indexes (the `X-Consul-Index` header's value too), runtime counters, `cpu_count`, `arch` in `/v1/agent/self` | | |
| openfga | the store's ULID (it comes back in a later request path, and the token round-trips) | RFC 3339 times | | |
| typesense | | `created_at` | each `X-TYPESENSE-API-KEY`, as `REDACTED[<key>]` | |
| mockserver | the expectation's UUID | | | |

A redaction is a literal swap: the secret is written as its placeholder,
and on playback the placeholder in the tape is swapped back before the
request is compared. Placeholders must not contain one another, hence
`REDACTED[admin]` rather than `REDACTED-admin` beside
`REDACTED-admin-wrong-password`.

## Where Servirtium comes from

`lib/servirtium_vcr` is a relative symlink to `../servirtium-vcr/core`, a
sibling checkout of https://github.com/servirtium/servirtium-vcr (recorded
against v2.0.0-alpha.11). `ae test` searches a project's `lib/` first, so
`import servirtium_vcr.vcr` resolves with no flags; point the symlink at
another checkout to use it. Only the tests that import
`testcontainers.servirtium` need it.
