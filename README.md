# testcontainers-ae

Throwaway containers for tests written in [Aether](https://github.com/aether-lang-dev/aether):
a port of the core of [testcontainers-go](https://github.com/testcontainers/testcontainers-go).
A test starts the real Redis, PostgreSQL or anything else with an image,
talks to it on a mapped port, and leaves nothing behind, even when it
crashes.

```aether
import std.spec
import std.tcp
import testcontainers as tc
import testcontainers.testing
import modules.redis

main() {
    fw = spec.init()
    if testing.skip_if_no_engine(fw) == 1 { return spec.run_summary(fw) }
    spec.describe(fw, "my cache") {
        spec.after_each() callback { testing.cleanup_all() }
        spec.it("talks to a real Redis") callback {
            c, err = redis.run("redis:7-alpine") {
                log_level(redis.LOG_LEVEL_VERBOSE)
            }
            testing.cleanup_container(c)
            spec.assert_ok(err, "redis starts")
            host, _ = tc.host(c)
            port, _ = tc.mapped_port(c, redis.PORT)
            sock, cerr = tcp.connect(host, port)
            spec.assert_ok(cerr, "connect")
            tcp.write(sock, "*1\r\n$4\r\nPING\r\n")
            pong, _ = tcp.read(sock, 64)
            spec.assert_str_eq(pong, "+PONG\r\n", "PING")
            tcp.tcp_close(sock)
        }
    }
    return spec.run_summary(fw)
}
```

Any image, without a module:

```aether
import testcontainers as tc
import testcontainers.wait

c, err = tc.run("nginx:alpine") {
    expose("80/tcp")
    env("NGINX_ENTRYPOINT_QUIET_LOGS", "1")
    file_content("<h1>hi</h1>", "/usr/share/nginx/html/index.html", 420)
    wait_for(wait.for_http("/") { with_status(200) })
}
defer tc.terminate(c)
url, _ = tc.endpoint(c, "80/tcp", "http")      // "http://localhost:32774"
code, out, _ = tc.exec(c, ["nginx", "-v"])
```

`DESIGN.md` has the whole API: the request setters, the container
operations, wait strategies, networks, lifecycle hooks, log consumers, the
reaper, configuration, and how each maps to testcontainers-go. `PORTING.md`
says what is ported, file by file, and the state of every module.

## What is here

- `testcontainers/` the core (`import testcontainers as tc`), with
  `wait/`, `network/`, `docker/` (the engine client) and `testing/`
  (std.spec helpers) under it.
- `modules/`, all of testcontainers-go's modules but two (the list, what
  each leaves out and which are tested live is in `PORTING.md`), Docker
  Compose included (`modules/compose`, through the compose CLI): `modules/redis`, the model every module
  port copies; `modules/postgres`, the model for a module whose container
  carries state; `modules/etcd`, the model for a module with options of its
  own (module settings) that starts several containers from one request
  (`tc.request_copy`). DESIGN.md section 9 is the porter's guide.
- `sql/`, a `database/sql`-shaped interface for Aether (`import sql`)
  with a PostgreSQL driver ported from jackc/pgx (`sql/postgres`) and a
  MySQL/MariaDB driver ported from go-sql-driver/mysql (`sql/mysql`,
  MPL-2.0), which `wait.for_sql` (Go's `ForSQL`) runs on. It imports
  nothing of testcontainers and will become a package of its own;
  `sql/README.md`.
- `tests/`, run against a real engine with `tests/run.sh`.
- Servirtium recordings of modules' HTTP APIs live in servirtium-vcr
  (`pre-recorded/from-testcontainers/`), which depends on this package.

## For test engineers

### Install

`ae add github.com/servirtium/testcontainers-ae` in the project that holds
your tests (the default branch, pinned by tree hash in `aether.toml`; a
`[patch]` entry points it at a local checkout instead). `ae test` reads
`[dependencies]` too (checked on Aether 0.897.0). Then
`import testcontainers`, `import testcontainers.wait` and
`import modules.redis` resolve (the package exports its root,
`modules = "."`). The toolchain needs the Unix-socket support in
`std.tcp` / `std.http.client`, on aether's `feat/unix-socket-client`
branch (0.885.0 dev tree), not yet in a release.

### The engine

Docker Engine on Linux, Docker Desktop, OrbStack, Colima, rootless or
rootful Podman on Linux, or a Podman machine on macOS: anything serving the
Docker Engine API on a Unix socket or plain `tcp://`. Nothing to configure
in the usual case: the library tries `DOCKER_HOST`, the properties file,
`/var/run/docker.sock`, the rootless Docker sockets, the Podman sockets
(a Podman machine's API socket on macOS included), OrbStack and Colima, in
that order (Go's order plus the last three; "Engine setup" below), and
uses the first that answers `/_ping`. Set `DOCKER_HOST` to choose. Podman
is detected, and the reaper is set up for it without a rootful machine.

### A first test

A test is a std.spec program, `tests/test_<thing>.ae`, run with `ae test`.
With a module (the README's first example is the whole file):

```aether
c, err = redis.run("redis:7-alpine") { log_level(redis.LOG_LEVEL_VERBOSE) }
testing.cleanup_container(c)            // removed after the case, even if it fails
spec.assert_ok(err, "redis starts")
port, _ = tc.mapped_port(c, redis.PORT) // talk to it on localhost:port
```

With any image: `tc.run(image) { expose(...); env(...); wait_for(...) }`
(the second example above); `DESIGN.md` section 2 lists every setter and
section 3 every wait strategy. Each container gets a random host port;
always wait for readiness (`for_log`, `for_listening_port`, `for_http`,
`for_exec`, `for_health_check`), never `sleep`. Start every `describe`
with `spec.after_each() callback { testing.cleanup_all() }`. If the test
process dies, the reaper (Ryuk) removes everything about 10 seconds later.

### Private registries

Images are pulled with the credentials in the Docker config, as `docker
pull` would: `DOCKER_AUTH_CONFIG`, else `$DOCKER_CONFIG/config.json` or
`~/.docker/config.json`; plain `auths` entries, and credential helpers
(`credHelpers` per registry, `credsStore` for `auths` entries without
credentials) run as `docker-credential-<name> get`. So `docker login` once
is enough. Podman's own `auth.json` is not read: log in with
`podman login --authfile ~/.docker/config.json` instead. Docker
Hub mirrors: `TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX`.

### A container that calls back to the test

```aether
c, err = tc.run("alpine:3") { host_access_port(port); cmd(["sleep", "300"]) }
// inside the container: http://host.testcontainers.internal:<port>/
```

On a Podman machine, Docker Desktop, OrbStack and Colima a service on the
host's `127.0.0.1` is reached; on Linux Docker and rootless Podman the
service must listen on `0.0.0.0` (DESIGN.md section 12; the test binds
`0.0.0.0` so it passes on both, and was run on a Podman machine and on
rootless Podman 6.1.4 on Linux). Bind `0.0.0.0` in your own tests to be
engine-independent.

### Reusing a container across runs

`reuse_by_name("orders-db")` in the block returns the running container
of that name instead of starting another. To keep it between test runs
(fast local loops), set `testcontainers.reuse.enable=true` in
`~/.testcontainers.properties` (or `TESTCONTAINERS_REUSE_ENABLE=true`): the
reaper then leaves it alone, and you remove it yourself (DESIGN.md
section 13). Leave the switch off in CI.

### Starting several at once

`tc.parallel([tc.container_request("redis:7-alpine") { ... }, ...], 0)`
starts them on worker threads and returns the containers and errors in
request order (DESIGN.md section 2).

### Recording the HTTP conversation, and replaying it without the container

Servirtium-in-the-middle recordings of modules' HTTP APIs (Vault, CouchDB,
Consul, OpenFGA, Typesense, MockServer, ...) live in
[servirtium-vcr](https://github.com/servirtium/servirtium-vcr), under
`pre-recorded/from-testcontainers/`: a test per service that starts the
container with this package and records its conversation as tapes any
language's Servirtium can replay. They moved there on 2026-11-07, with the
recorder, so this package does not depend on Servirtium.

### Running some of the tests

`ae test tests/test_orders.ae tests/test_billing.ae` runs those files;
`ae test` runs every `tests/test_*.ae`. In this repository
`tests/run.sh test_redis.ae ...` does the same, removes the images each
file pulled, and checks nothing is left running. There is no per-case
filter in std.spec: split slow cases into their own file, or guard them
with `spec.it_when(cond, name, reason)` as the gated tests here do.

### "Tested live" and "compile-checked"

`PORTING.md` marks each module. **Tested live**: its test starts the real
image and talks to the service, and it passed against Podman on an arm64
Mac. **Compile-checked**: the module and its test compile and the
engine-free parts run, but the live case is skipped unless the variable
named there is set, because it needs something this project's Podman
machine does not give (a privileged container, Docker Desktop, a large
emulator, an amd64-only image). Expect to debug a compile-checked module
the first time you use it live.

### Known limits

- SQL: `wait.for_sql` and `sql` handles work for PostgreSQL (and
  CockroachDB, which speaks its protocol) through `sql/postgres`, and for
  MySQL and MariaDB through `sql/mysql`; other databases have no driver
  yet, so their modules wait on the image's own client or a log line and
  return connection strings. The drivers' limits (no pool, rows read
  whole, TLS that always verifies, so `sslmode=require` and
  `tls=skip-verify` are refused) are in `sql/README.md`.
- TLS waits verify against a CA file or not at all (`with_tls_ca_file`,
  `with_tls_config_from`, `with_allow_insecure`); no client certificates
  (mutual TLS), and a server name other than the host dialled only for
  loopback names.
- TLS to the engine itself (`DOCKER_TLS_VERIFY`) is not supported.
- Docker Compose runs through the compose CLI, which must be installed.
- `modules/compose` reads compose files with `testcontainers.miniyaml`, a
  pure-Aether YAML subset reader, not std.yaml: the released Aether
  toolchains are built without libfyaml, so std.yaml is unavailable on
  macOS and Linux alike.
- Built and run on macOS (arm64) with a Podman machine. Docker and Linux
  engines speak the same API and the code covers them, but the full suite
  has not been run there; Windows is untested.

## Engine setup

Any engine that serves the Docker Engine API on a Unix socket (or plain
`tcp://`): Docker, Docker Desktop, OrbStack, Colima, Podman. The engine is
found the way testcontainers-go finds it (`DESIGN.md` section 8): `tc.host`
in `~/.testcontainers.properties`, `DOCKER_HOST`, `/var/run/docker.sock`,
`docker.host` in the properties file, the rootless Docker sockets, then the
Podman sockets, including a Podman machine's API socket on macOS
(`$TMPDIR/podman/*-api.sock`), OrbStack and Colima. Each is pinged; the
first that answers is used.

**Podman** works as it is, rootless or rootful, on Linux or in a Podman
machine on macOS, with the reaper on: the library asks Podman where its
socket is inside the machine and mounts that into Ryuk, and runs Ryuk
privileged, as Podman needs. No `ryuk.container.privileged` or rootful
machine is needed, unlike testcontainers-go on macOS. To be explicit:

```sh
export DOCKER_HOST="unix://$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}')"
```

TLS to a remote engine (`DOCKER_TLS_VERIFY`) is not supported.

### Environment and properties

| Variable | Property | Effect |
|---|---|---|
| `DOCKER_HOST` | `docker.host` | The engine (`unix:///path`, `tcp://host:port`). |
| | `tc.host` | An engine to try before everything else. |
| `DOCKER_API_VERSION` | | Pin the API version instead of negotiating. |
| `TESTCONTAINERS_RYUK_DISABLED` | `ryuk.disabled` | `true`: no reaper; only explicit terminate cleans up. |
| `TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED` | `ryuk.container.privileged` | Run Ryuk privileged (always so on Podman). |
| `TESTCONTAINERS_RYUK_RECONNECTION_TIMEOUT` | `ryuk.reconnection.timeout` | How long Ryuk waits after the last connection closes (10s). |
| `TESTCONTAINERS_RYUK_CONNECTION_TIMEOUT` | `ryuk.connection.timeout` | How long Ryuk waits for a first connection (1m). |
| `TESTCONTAINERS_RYUK_VERBOSE` | `ryuk.verbose` | Ryuk's verbose log. |
| `RYUK_PORT` | | The port Ryuk listens on (8080). |
| `TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX` | `hub.image.name.prefix` | A registry mirror for Docker Hub images (`redis:7` becomes `<prefix>/redis:7`). |
| `TESTCONTAINERS_SESSION_ID` | `session.id` | The session id (random per process otherwise). |
| `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE` | | The socket path Ryuk mounts. |
| `TESTCONTAINERS_HOST_OVERRIDE` | | The host published ports are reached on. |
| `TESTCONTAINERS_PROVIDER` | `provider` | `podman` to treat the engine as Podman (detected anyway). |
| `DOCKER_CONFIG` | | Where `config.json` with registry credentials is (`~/.docker`). |
| `DOCKER_AUTH_CONFIG` | | A whole Docker config (JSON) to use instead of `config.json`. |
| `TESTCONTAINERS_REUSE_ENABLE` | `testcontainers.reuse.enable` | `true`: containers made with `reuse_by_name` are kept from the reaper and outlive the run. |

## Tests

```sh
tests/run.sh                  # every tests/test_*.ae, then checks nothing is left running
tests/run.sh test_redis.ae    # one
```

Every test that needs an engine skips (and says why) when there is none.
`tests/test_config.ae` needs no engine.

## Known gaps

In this library: see "Known limits" above and `PORTING.md`.

In Aether (0.885.0 dev tree), found while porting, each with a repro in
the port's report:

- UFCS (`value.f()` for `f(value)`) does not resolve functions of a module
  imported with a dotted path or an alias (`import testcontainers.wait`,
  `import strat as st`), and a fluent `spec.expect_*` chain does not resolve
  inside a helper function. So wait strategies take their modifiers in a
  trailing block, `wait.for_log("x") { with_occurrence(2) }`, which works,
  rather than as a chain.
- `string.concat(null, x)` returns `""`; a `heap.new` struct's string fields
  start null.
- A string literal passed to an `int` parameter of a std extern
  (`string.pad_start(s, 4, "0")`) passes the type checker and fails in the C
  compiler.
- A local `ptr[] xs = []` declaration does not parse (`let xs: ptr[] = []`
  does; `string[] xs = []` does). Nor does `long[] xs = []`, `n: long = 0`
  or `mod.Type[] xs = []` (the `let` form does).
- Importing a second module whose last path segment is the same as a first
  one's, under an alias (`import modules.postgres` and
  `import sql.postgres as pgsql`), makes the first one's name unknown in
  type positions (`*postgres.PostgresContainer`: "unknown module
  'postgres' in the type"), while calls through it still resolve. Alias
  both (`import modules.postgres as pgmod`) or keep the type out of
  signatures.
- `std.cryptography.tls13_client.connect_socket` (TLS over a socket the
  caller holds, as PostgreSQL's SSLRequest needs) always verifies the chain
  and the host name and presents no client certificate; the verification
  bits and mTLS exist inside (`connect_full`, `connect_mtls`) but are not
  exported for an adopted socket. So `sql/postgres` cannot do
  `sslmode=require`'s unverified TLS, `verify-ca`'s chain-only check, or
  client-certificate authentication (`sql/README.md`); for the same
  reason `sql/mysql` refuses `tls=skip-verify` and makes `tls=preferred`
  verify.
- `string.join` takes a `*StringSeq`, but a `string[]` passes the type
  checker: `string[] xs = []; xs.push("a"); xs.push("b");
  println(string.join(xs, ","))` compiles with only a C warning
  (incompatible pointer types) and prints `b`.
- `std.cryptography.rsa` has RSA-OAEP with SHA-256 only; MySQL's
  caching_sha2_password / sha256_password want OAEP with SHA-1, so
  `sql/mysql` builds that block itself over `rsa.raw_encrypt`.
  `std.cryptography.ed25519` signs only from a 32-byte seed, so MariaDB's
  `client_ed25519` (the scalar of SHA-512 of a password of any length) is
  not ported.

## Credits

testcontainers-ae is a port of testcontainers-go
(https://github.com/testcontainers/testcontainers-go, MIT, portions copyright
(c) 2017-2019 Gianluca Arbezzano and the testcontainers-go contributors),
ported from commit
55f58feb2510720e08aab90be005128aa86ddcdf (main, 2026-11-04). Each ported file names the Go files it came
from in its first line. The Redis and PostgreSQL test data files are copied
from the Go modules' `testdata/`. See `LICENSE` and `NOTICE`.

`sql/postgres/` is a port of jackc/pgx (https://github.com/jackc/pgx, MIT,
copyright (c) 2013-2021 Jack Christensen), v5.9.2: `pgproto3/`, `pgconn/`
and `stdlib/`, with the text-format parts of `pgtype/`; each ported file
names the pgx files it came from in its first lines. `sql/LICENSE` carries
pgx's license and `sql/NOTICE` lists what came from where.

`sql/mysql/` is a port of go-sql-driver/mysql
(https://github.com/go-sql-driver/mysql, Mozilla Public License 2.0,
Copyright 2012 The Go-MySQL-Driver Authors), v1.9.3 (commit 62984ad). It
keeps the MPL-2.0: every ported file carries the MPL notice and names the
Go files it came from, `sql/mysql/LICENSE` has the license text,
`sql/mysql/AUTHORS` the authors, and `sql/NOTICE` the per-file
provenance. `tests/test_sql_mysql_unit.ae`, which carries the driver's
test vectors, is MPL-2.0 too; the rest of the repository is MIT.
