# testcontainers-ae: design

This is the API of the core, how testcontainers-go's concepts map onto it,
and what is deliberately different. It is written for two readers: a person
writing tests with it, and an agent porting one of testcontainers-go's
`modules/<name>` against it (section 9 is theirs).

## 1. Shape

| Import | Namespace | File | What |
|---|---|---|---|
| `import testcontainers as tc` | `tc` (or `testcontainers`) | `testcontainers/module.ae` | The request DSL, `run`, the container operations, the session, the reaper, lifecycle hooks, log consumers, image name substitution. Most programs import only this and `wait`. |
| `import testcontainers.wait` | `wait` | `testcontainers/wait/module.ae` | Wait strategies and their modifiers. |
| `import testcontainers.network` | `network` | `testcontainers/network/module.ae` | Creating and removing user-defined networks. |
| `import testcontainers.docker` | `docker` | `testcontainers/docker/module.ae` | The engine client underneath: discovery, configuration, the Engine API over a Unix socket (or plain `tcp://`), JSON, stream demultiplexing, the `Container` and `Network` structs. Imported by modules and by programs that want raw access. |
| `import testcontainers.testing` | `testing` | `testcontainers/testing/module.ae` | `std.spec` helpers: skip when there is no engine, clean up containers and networks after a case. |
| `import modules.redis` | `redis` | `modules/redis/module.ae` | The model module. |
| `import sql` | `sql` | `sql/module.ae` | A `database/sql`-shaped interface with drivers registered by name (section 14). Not part of testcontainers: it imports none of it. |
| `import sql.postgres as pgsql` | `pgsql` | `sql/postgres/module.ae` | The PostgreSQL driver, a port of jackc/pgx (`pgproto3`, `pgconn` under it). |

The layering is strictly downward: `docker` imports only std; `wait` and
`network` import `docker`; `testcontainers` imports all three; modules import
`testcontainers`, `wait` and `docker`. Aether has no interfaces, so where Go
has `wait.StrategyTarget` (an interface the container satisfies), the wait
module takes the concrete `*docker.Container`, which is why the container
struct lives in the bottom module.

## 2. Running a container

```aether
import testcontainers as tc
import testcontainers.wait

main() {
    c, err = tc.run("redis:7-alpine") {
        expose("6379/tcp")
        env("REDIS_ARGS", "--save ''")
        wait_for(wait.for_log("Ready to accept connections") { with_startup_timeout(30s) })
    }
    defer tc.terminate(c)          // null-safe, and safe after a failed start
    if err != "" { println("start: ${err}"); return 1 }

    hostport, _ = tc.endpoint(c, "6379/tcp", "")   // "localhost:32771"
    ...
}
```

`tc.run(image) { ... }` is an Aether **builder** function (`builder run(...)
with request_new`). The trailing block runs **first** and fills a
`*tc.Request` through setter calls; then `run` resolves the image, pulls or
builds it, creates the container, copies files in, starts it, runs the wait
strategy, and returns `(*docker.Container, string)`. This is the same
mechanism as `sandbox.new("x") { grant_... }` (a `_ctx: ptr` first parameter
the compiler injects inside the block), except that `run` must not do its work
until the block has finished, which is exactly what `builder` gives (block
first, function second). Inside the block the setters are written bare: Aether
resolves a bare name in a block attached to `tc.run` through the `tc`
namespace first (block-receiver scoping). `tc.env(...)` works too, and is how
a module's block reaches the core setters.

Like Go's `Run`, a container that was created is returned **with** the error
when a later step fails (start, copy, wait), so the caller can terminate it;
`tc.terminate(null)` is a no-op. Without a block (`tc.run("alpine:3")`) the
request is empty apart from the image: the compiler passes **no** request at
all then (`_builder` is null, the factory is not called), which `run`
handles and a module's `run` must handle too (section 9).

Several at once (Go's `ParallelContainers`): `tc.container_request(image)
{ ... }` is a request with its image, not yet run (Go's
`GenericContainerRequest`), and `tc.parallel(reqs, workers)` runs them on
up to `workers` `std.worker` threads (0 for 8, Go's default):

```aether
reqs = [tc.container_request("redis:7-alpine") { expose("6379/tcp") },
        tc.container_request("nginx:alpine") { expose("80/tcp") }]
cs, errs, err = tc.parallel(reqs, 0)       // ptr[], string[], string
redis = cs[0] as *docker.Container         // null when nothing was made; errs[0] says why
```

The client, the reaper and the reuse lock are set up before the threads
start; each thread then runs `run_request`. Hooks, matchers and log
consumers run on those threads, so they must be thread-safe, as in Go.

Two non-builder forms exist for code that assembles requests itself:

```aether
r = tc.request_new()                  // a *tc.Request as a ptr
tc.expose(r, "80/tcp")                // every setter can be called with the request first
c, err = tc.run_request(r, "nginx:alpine")   // takes ownership of r
```

### Request setters (Go's `ContainerRequest` fields and `With*` options)

| Setter | Go | Notes |
|---|---|---|
| `expose(port)` | `ExposedPorts`, `WithExposedPorts` | `"6379"`, `"6379/tcp"`, `"53/udp"`; `"8080:80/tcp"` pins host port 8080. Each exposed port is published to a random host port unless pinned. |
| `env(key, value)`, `unset_env(key)` | `Env`, `WithEnv` | A later value for a key replaces the earlier one; `unset_env` removes the key (Go's `delete(req.Env, key)`). |
| `cmd(args: string[])`, `cmd_arg(arg)` | `Cmd`, `WithCmd`, `WithCmdArgs` | `cmd` replaces, `cmd_arg` appends one. |
| `entrypoint(args: string[])`, `entrypoint_arg(arg)` | `Entrypoint`, `WithEntrypoint`, `WithEntrypointArgs` | |
| `label(key, value)` | `Labels`, `WithLabels` | A key starting `org.testcontainers` is refused at run, as in Go. |
| `name(n)` | `Name`, `WithName` | |
| `hostname(h)`, `workdir(d)`, `user(u)`, `privileged()`, `extra_host("h:ip")`, `cap_add(c)`, `cap_drop(c)`, `shm_size(bytes)`, `auto_remove()`, `network_mode(m)` | deprecated `ContainerRequest` fields | Kept as setters: in Aether they are as cheap as the modifier, and read better. |
| `bind(host_path, target)`, `bind_ro(host_path, target)` | `Mounts` (`BindMount`) | |
| `volume(name, target)` | `Mounts` (`VolumeMount`) | Labelled with the session so the reaper removes it. |
| `tmpfs(target, options)` | `Tmpfs`, `WithTmpfs` | |
| `with_network(name)`, `network_alias(name, alias)` | `Networks`, `NetworkAliases`, `network.WithNetwork` | Aliases need a user-defined network. |
| `file(host_path, container_path, mode)`, `file_content(text, container_path, mode)` | `Files`, `WithFiles` (`ContainerFile` with `HostFilePath` or `Reader`) | Copied after create, before start. A file lands exactly at `container_path`, missing parent directories made. A directory host path is Go's rule: the tree keeps the host directory's base name and is extracted into the **parent** of `container_path`, so `file("testdata/data", "/data", 0)` is `/data` (not `/data/data`), `"/srv/"` gives `/srv/data`, and `"/opt/other"` gives `/opt/data`; that parent must exist. |
| `wait_for(s)`, `additional_wait(s)`, `wait_deadline(d)` | `WaitingFor`, `WithWaitStrategy`, `WithAdditionalWaitStrategy`, `...AndDeadline` | `additional_wait` makes the strategy `for_all(existing, s)`. |
| `log_consumer(f)` | `LogConsumerCfg`, `WithLogConsumers` | `f` is `\|kind: int, line: string\|`; kind 1 stdout, 2 stderr. See section 6. |
| `config_modifier(f)`, `host_config_modifier(f)`, `endpoint_settings_modifier(f)` | the three modifiers | `f` is `\|cfg: ptr\|` and gets the std.json object about to be sent (`Config`, `HostConfig`, `NetworkingConfig.EndpointsConfig`), to set any field the API has. |
| `on_pre_create(f)` ... `on_post_terminate(f)` | `LifecycleHooks` | `f` is `\|c: *docker.Container\| { ...; return "" }` returning an error string. Section 5. |
| `startup_command(cmd)`, `after_ready_command(cmd)` | `WithStartupCommand`, `WithAfterReadyCommand` | Exec'd at post-start and post-ready. |
| `always_pull()`, `platform(p)` | `AlwaysPullImage`, `ImagePlatform` | |
| `image_substitutor(f)` | `ImageSubstitutors` | `f` is `\|image: string\| -> string`. |
| `from_dockerfile(context_dir, dockerfile)`, `build_arg(k, v)`, `build_tag(t)`, `keep_built_image()` | `FromDockerfile` | Builds before create; `run("")` with a Dockerfile is fine. |
| `no_start()` | `WithNoStart` | Created, not started; `tc.start(c)` later runs hooks and wait. |
| `set_setting(key, value)` | a module's own options struct | A module setting, never sent to the engine: section 9. |
| `host_access_port(port)` | `HostAccessPorts`, `WithHostPortAccess` | The container reaches `host.testcontainers.internal:<port>` (`tc.HOST_INTERNAL`) on the test's host: section 12. |
| `reuse_by_name(name)` | `WithReuseByName`, `Reuse` | The container of that name if it exists, else a new one: section 13. |
| `with_image(image)` | `WithImage` | The image when `run_request` (or `parallel`) is given `""`. |

### Container operations (Go's `Container` interface)

All take the `*docker.Container` first (written `tc.terminate(c)`; the UFCS
spelling `c.terminate()` waits on the Aether gap in README "Known gaps"):

| Aether | Go | Result |
|---|---|---|
| `tc.id(c)`, `tc.name_of(c)`, `tc.image_of(c)`, `tc.session_id()` | `GetContainerID`, `Name`, `SessionID` | `string` (`state` is an Aether keyword, hence `state_of`, and `name_of` / `image_of` match it) |
| `tc.host(c)` | `Host` | `(string, err)`; `"localhost"` for a Unix-socket engine, the `tcp://` host otherwise, `TESTCONTAINERS_HOST_OVERRIDE` wins. |
| `tc.mapped_port(c, "6379/tcp")` | `MappedPort` | `(int, err)` |
| `tc.endpoint(c, port, proto)` | `PortEndpoint`, `Endpoint` (port `""` = lowest exposed) | `(string, err)`: `"proto://host:port"`, or `"host:port"` for proto `""` |
| `tc.inspect(c)` | `Inspect` | `(ptr, err)`: the parsed JSON document, the caller `json.free`s it |
| `tc.state_of(c)` | `State` | `(docker.State, err)`: status, running, exit code, OOM, health |
| `tc.is_running(c)` | `IsRunning` | `bool` |
| `tc.start(c)`, `tc.stop(c, timeout)`, `tc.terminate(c)`, `tc.terminate_graceful(c, timeout)` | `Start`, `Stop`, `Terminate` | error string; `stop` takes a `Duration` (`10s`). `terminate` kills and removes at once (`docker rm -fv`; on Podman a plain forced remove would wait out a 10s stop timeout first); `terminate_graceful` stops first, with the stop hooks. |
| `tc.logs(c)` | `Logs` | `(string, err)`: stdout and stderr, demultiplexed, in order |
| `tc.exec(c, cmd)` | `Exec` | `(exit_code, output, err)`; output demultiplexed |
| `tc.exec_with(c, cmd, user, workdir, env: string[])` | `Exec` + `exec.WithUser/WithWorkingDir/WithEnv` | `(*docker.ExecResult, err)` with `stdout`, `stderr`, `output` and `exit_code` |
| `tc.copy_to_container(c, text, path, mode)`, `tc.copy_file_to_container(c, host, path, mode)`, `tc.copy_dir_to_container(c, host_dir, path, mode)` | the `CopyTo*` trio | error string; a file or directory lands as with the `file` setter above |
| `tc.copy_file_from_container(c, path)` | `CopyFileFromContainer` | `(string, err)`, binary-safe |
| `tc.container_ip(c)`, `tc.container_ips(c)`, `tc.networks(c)`, `tc.network_aliases(c, net)` | same | |

## 3. Wait strategies

```aether
wait.for_log("ready") { with_occurrence(2) }
wait.for_log("listening on .* port=[0-9]+") { as_regexp() }
wait.for_listening_port("5432/tcp")          // internal (in-container) + external (host) check
wait.for_exposed_port()                      // the lowest exposed port
wait.for_mapped_port("80/tcp")               // only that the port is mapped
wait.for_http("/health") { with_port("8080/tcp"); with_status(200) }
wait.for_http("/") { with_response_matcher(|body: string| -> string.contains(body, "ok") == 1) }
wait.for_http("/") { with_port("9200/tcp"); with_allow_insecure() }   // HTTPS, no verification
wait.for_http("/") { with_tls_ca_file("/path/ca.pem") }               // HTTPS, verified against a CA file
t = wait.for_tls_root_cas(["/certs/ca.crt"])                           // read the CA out of the container
wait.for_all([t, wait.with_tls_config_from(wait.for_http("/health"), t)])  // HTTPS verified against it
wait.for_tls_cert("/certs/client.crt", "/certs/client.key") { with_root_cas(["/certs/ca.crt"]); with_server_name("127.0.0.1") }
wait.for_health_check()
wait.for_exec(["pg_isready"]) { with_exit_code(0) }
wait.for_exit()
wait.for_file("/tmp/ready") { with_file_matcher(|content: string| -> string.contains(content, "done") == 1) }
wait.with_query(wait.for_sql("5432/tcp", "postgres", |host: string, port: int| -> "postgres://u:p@${host}:${port}/db?sslmode=disable"), "SELECT 1")
wait.for_all([wait.for_log("a"), wait.for_listening_port("80/tcp")]) { with_deadline(30s) }
wait.for_any([wait.for_log("a"), wait.for_log("b")])
wait.with_startup_timeout(wait.for_func(|c: *docker.Container| { ...; return "" }), 5s)   // Go's custom Strategy
```

Every constructor returns a `*wait.Strategy`. Every modifier takes the
strategy as its first parameter, named `_ctx`, and returns it, so it works
three ways: in a trailing block on the constructor (the constructor runs
first and its strategy is the block's context, so `with_occurrence(2)` there
is `wait.with_occurrence(s, 2)`); called with the strategy,
`wait.with_occurrence(s, 2)`; and chained, `wait.for_log("x").with_occurrence(2)`,
which is Go's `ForLog("x").WithOccurrence(2)` but needs UFCS on a dotted
import, an Aether gap today (README "Known gaps"). The block is the form to
use. `for_func`'s last parameter is its closure, so it takes no modifier
block: call the modifier around it, as above. Matchers are closures:
status and exit-code matchers `|n: int| -> bool`, response and file
matchers `|s: string| -> bool`. Common modifiers: `with_startup_timeout(d)`
(default 60s, Go's default), `with_poll_interval(d)` (default 100ms).
Timeouts are `Duration` literals. `for_all` / `for_any` take a `ptr[]` of
strategies (an array literal of them converts).

**How a strategy runs** is the main difference from Go. Go's strategies each
own a loop and `ForAny` runs them in goroutines. Here each kind has a single
**probe** (`fn probe(s, c) -> (ready, err, fatal)`: one look at the logs, one
dial, one HTTP request...), and one driver loop polls it until the deadline.
`for_all` drives its children one after another (each with its own timeout,
as Go does, under the optional overall deadline); `for_any` interleaves the
children's probes on one loop and returns at the first that is ready, which
gives Go's semantics without threads. Before each probe the container's state
is checked, so a container that exited or was OOM-killed fails the wait at
once with its exit code, as Go's `checkTarget` does.

`wait.until_ready(s, c)` runs a strategy against a running container, the
equivalent of `WaitUntilReady(ctx, target)`.

**TLS.** Go's `ForHTTP(...).WithTLS(true, cfg)` takes a `*tls.Config`;
std.http.client takes a CA file (`set_cafile`) or no verification
(`set_insecure`), so the HTTP strategy has `with_tls()` (the system trust
store), `with_allow_insecure()` (Go's `WithAllowInsecure(true)`),
`with_tls_ca_file(host_path)`, and `with_tls_config_from(t)`, the CA that a
`for_tls_cert` / `for_tls_root_cas` strategy `t` read from the container
(Go passes `t.TLSConfig()`). That strategy (Go's `wait/tls.go`) waits for
its PEM files in the container, checks they are PEM, writes the CA bundle
to a host temp file (`wait.tls_ca_file(t)`, left behind like any temp file)
and keeps the PEMs (`tls_ca_pem`, `tls_cert_pem`, `tls_key_pem`). Limits,
from std.http.client: no client certificates (Go's `ForTLSCert` puts the
pair in the config for mutual TLS; here the PEMs are only handed back), and
the name verified is the host dialled, so `with_server_name` (Go's
`WithServerName`) works only when it and the host are both loopback
(`127.0.0.1` for `localhost`: cockroach's node certificate), where the
probe dials the name instead; any other name fails the wait and says why.
**SQL.** `wait.for_sql(port, driver, url_fn)` is Go's `ForSQL`: `url_fn`
is `|host: string, port: int| -> string`, the data source name for the
host and the mapped port, and `driver` a name registered with `sql`
(section 14), so the program registers the driver first
(`pgsql.register()` for `"postgres"`, `"pgx"`, `"pgx/v5"`). Each poll
opens the database, runs the query (`SELECT 1`, or `with_query`'s) and
closes it; Go keeps one `sql.DB` whose pool reconnects, which comes to the
same. Its closure is the last parameter, so its modifiers are called
around it, as for `for_func`. For a database without a driver yet, wait
with `for_exec` on its own client (`mysqladmin ping`).

## 4. Networks

```aether
import testcontainers.network

n, err = network.new_random() {   // a random name, labelled with the session
    driver("bridge")
    internal()
    label("purpose", "test")
}
defer network.remove(n)
a, _ = tc.run("nginx:alpine") { with_network(n.name); network_alias(n.name, "web") }
b, _ = tc.run("alpine:3") { with_network(n.name); cmd(["sleep", "60"]) }
code, out, _ = tc.exec(b, ["wget", "-qO-", "http://web/"])
```

`network.new(name)` takes a name; `network.new_random()` makes one up.

## 5. Lifecycle hooks

Go's `ContainerLifecycleHooks` struct of eleven hook slices becomes eleven
setters, each appending one closure: `on_pre_build`, `on_post_build`,
`on_pre_create`, `on_post_create`, `on_pre_start`, `on_post_start`,
`on_post_ready`, `on_pre_stop`, `on_post_stop`, `on_pre_terminate`,
`on_post_terminate`. A hook is `|c: *docker.Container| { ... return "" }`;
the container exists (with its id) from post-create on, before that its
`id` is `""`. A non-empty return stops the stage and is the run's (or the
stop's, or the terminate's) error, as in Go. The default hooks Go installs
(copy files, follow logs, wait, exec startup and after-ready commands) are
not hooks here: they are steps of `run`, at the same points.

## 6. Logs and log consumers

`tc.logs(c)` returns the whole log so far, `tc.logs_split(c)` stdout and
stderr apart. A log consumer (`log_consumer(|kind: int, line: string| { ... })`)
is fed the followed log frame by frame (Go's `Log{LogType, Content}`; a frame
is a line for line-buffered output) from a pool thread (`std.worker`), from
start until the container stops or is terminated; `terminate` waits for its
consumers to see the end. Go calls its consumers from a goroutine too, so a
consumer must be thread-safe in both. `tc.logs_follow(c, f)` attaches one to
a running container.

## 7. The reaper (Ryuk) and the session

A session is one process. Its id (`tc.session_id()`, overridable with
`TESTCONTAINERS_SESSION_ID`) labels every container, network, volume and
built image: `org.testcontainers=true`, `org.testcontainers.lang=aether`,
`org.testcontainers.version`, `org.testcontainers.sessionId`, and
`org.testcontainers.reap=true` while Ryuk is on.

Before the first container of a session, `run` starts `testcontainers/ryuk`
(named `reaper_<session>`, the engine's socket bind-mounted at
`/var/run/docker.sock`), dials its port, sends the session's label filter, and
keeps the connection open in a module-level variable for the life of the
process. When the process ends, for any reason, the kernel closes it, and Ryuk
removes everything labelled with the session after its reconnection timeout
(10s by default). Nothing in the test has to run for that to happen, which is
the point: a crashed or killed test leaks nothing.

Which socket to mount is the part that differs per engine (section 8).
`TESTCONTAINERS_RYUK_DISABLED=true` turns the reaper off; then only explicit
`tc.terminate` / `network.remove` (or the `testing` helpers) clean up.

## 8. The engine, configuration and Podman

Discovery follows Go's order, each candidate checked with `GET /_ping`:
`tc.host` in `~/.testcontainers.properties`, `DOCKER_HOST`, `/var/run/docker.sock`,
`docker.host` in the properties file, the rootless Docker sockets
(`$XDG_RUNTIME_DIR/docker.sock`, `~/.docker/run/docker.sock`,
`~/.docker/desktop/docker.sock`, `/run/user/<uid>/docker.sock`), and then,
beyond Go, the Podman sockets (`$XDG_RUNTIME_DIR/podman/podman.sock`,
`/run/podman/podman.sock`, and on macOS every Podman machine's API socket
`$TMPDIR/podman/*-api.sock`) and the OrbStack and Colima sockets. `unix://`
and plain `tcp://` hosts work; TLS (`DOCKER_TLS_VERIFY`) is refused with an
error that says so.

The API version is negotiated as moby's client does: `GET /_ping` gives the
server's `Api-Version`; the client uses the lower of that and its own maximum
(1.44), unless `DOCKER_API_VERSION` pins one.

Registry credentials (Go's `docker_auth.go`): `DOCKER_AUTH_CONFIG` (the
JSON itself), else `config.json` in `$DOCKER_CONFIG` or `~/.docker`. An
`auths` entry for the image's registry gives its `auth` (or
`username`/`password`, or `identitytoken`); an `auths` entry without
credentials, or a `credHelpers` entry, runs the credential helper
(`credHelpers[registry]`, else `credsStore`): `docker-credential-<name> get`
with the server address on stdin, its `Username`/`Secret` JSON becoming the
pull's `X-Registry-Auth` (a `<token>` user makes the secret an identity
token). As in Go, a registry with no entry in either is pulled anonymously
without asking `credsStore`. `docker.registry_auth_lookup(registry)` is the
lookup, for a caller of its own.

Configuration (`docker.Config`, read once): the properties file keys
`docker.host`, `tc.host`, `hub.image.name.prefix`, `ryuk.disabled`,
`ryuk.container.privileged`, `ryuk.reconnection.timeout`,
`ryuk.connection.timeout`, `ryuk.verbose`, `session.id`, `provider`, and the
environment variables that override them (`TESTCONTAINERS_RYUK_DISABLED`,
`TESTCONTAINERS_RYUK_CONTAINER_PRIVILEGED`, `TESTCONTAINERS_HUB_IMAGE_NAME_PREFIX`,
`TESTCONTAINERS_SESSION_ID`, `TESTCONTAINERS_RYUK_VERBOSE`,
`TESTCONTAINERS_RYUK_RECONNECTION_TIMEOUT`,
`TESTCONTAINERS_RYUK_CONNECTION_TIMEOUT`, `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE`,
`TESTCONTAINERS_HOST_OVERRIDE`, `TESTCONTAINERS_PROVIDER`).

**Podman.** An engine is Podman when `/version` names a "Podman Engine"
component (or `provider=podman`). Then:

- the default bridge network is `podman`, not `bridge`;
- the socket Ryuk needs is the one *inside the machine or host that runs the
  containers*, not the client's: on macOS the client's socket is a forwarded
  file on the Mac, which means nothing inside the VM. Go takes the
  `DOCKER_HOST` path and documents that macOS needs a rootful machine and
  manual setup. Here the socket comes from Podman's own
  `GET /libpod/info` (`host.remoteSocket.path`, e.g.
  `/run/user/501/podman/podman.sock` for a rootless machine), which is right
  for rootless and rootful, Linux and macOS alike;
  `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE` still wins;
- Ryuk runs privileged, as Go requires for Podman: the machine has SELinux
  on, and a privileged container is not relabelled, which is what lets it
  connect to the socket. (`ryuk.container.privileged` / the env variable
  still force it for Docker.)
- `tc.host` is `localhost`: Podman machine forwards published ports to the
  Mac's loopback. That forwarder (gvproxy) **accepts a connection on a
  published port even when nothing listens in the container**, so an
  external-only port check (`skip_internal_check()`) passes at once and
  proves nothing there; `for_listening_port`'s internal check is what
  tells (tests/test_wait.ae has the case). Ryuk's own wait is its "Started"
  log line plus the port, and the handshake is retried until Ryuk ACKs.
- Podman ignores the labels in a mount's `VolumeOptions`, so a named volume
  is created first (`POST /volumes/create`, labelled with the session) and
  then mounted, on both engines, which is what lets the reaper remove it.

## 9. For module porters

The model is `modules/redis/module.ae`, with its test in
`tests/test_redis.ae`. A module is a directory `modules/<name>/module.ae`
(Go's `modules/<name>/<name>.go`), first line naming the Go file it came from:

```aether
// Ported from testcontainers-go modules/redis/redis.go
import testcontainers as tc
import testcontainers.wait
import testcontainers.docker

exports(run, connection_string, log_level, snapshotting, config_file)

// The module's defaults, applied BEFORE the caller's block, as Go applies a
// module's GenericContainerRequest before the caller's options.
redis_request_new() -> ptr {
    r = tc.request_new()
    tc.expose(r, "6379/tcp")
    tc.wait_for(r, wait.for_log("* Ready to accept connections"))
    return r
}
redis_request_free(p: ptr) { tc.request_free(p) }   // the builder's early-exit release

// A module option: a setter on the same request, so the caller's block can
// mix it with the core ones (`log_level("verbose"); tc.env("A", "b")`).
log_level(_ctx: ptr, level: string) { tc.cmd_arg(_ctx, "--loglevel"); tc.cmd_arg(_ctx, level) }

builder run(image: string) with redis_request_new -> (*docker.Container, string) {
    r = _builder
    if r == null { r = redis_request_new() }   // no block: no request at all
    return tc.run_request(r, image)
}

connection_string(c: *docker.Container) -> (string, string) { ... }
```

Rules of thumb:

1. **Go's `Run(ctx, img, opts...)` is `builder run(image) with <name>_request_new`**,
   and it returns `(*docker.Container, string)`. A module that needs more
   state keeps it in a struct of its own that holds the container, as Go's
   module containers embed `*DockerContainer`: `modules/postgres` is that
   model (`PostgresContainer { container, user, password, db_name, ... }`,
   `run` returning `(*PostgresContainer, string)`). Export the factory and
   `<name>_request_free` too (the compiler calls the free on an early exit
   from the block). Start from the factory when `_builder` is null.
2. **Defaults go in the factory**, so the caller's block overrides them. A
   Go option that edits the request (`WithLogLevel`) is a `_ctx: ptr` setter
   that calls the core setters with `_ctx`. Name it as Go's option without
   `With` (`WithSnapshotting` -> `snapshotting`). A Go option that needs to
   run after the defaults *and* see them (rare) can read the request in
   `run` before calling `tc.run_request`: `tc.req_env(r, key)`,
   `tc.req_has_env(r, key)` (Go's `_, ok := req.Env[key]`),
   `tc.req_env_keys(r)` and `tc.req_env_list(r)` (Go's `range req.Env`),
   `tc.req_has_cmd_arg(r, arg)` and friends, and edit it with the setters
   (`tc.unset_env(r, key)` is Go's `delete(req.Env, key)`).
   **A Go option that only sets the module's own options** (Go keeps them
   in an options struct, `WithNodes`, `WithClusterToken`, an SSL config
   fragment) is a setter that leaves a **module setting** on the request:
   `tc.set_setting(_ctx, "etcd.nodes", "a,b,c")`, read back in `run` with
   `tc.req_setting(r, key)` (`""` when unset) or `tc.req_has_setting(r, key)`.
   Settings are strings, a later value replaces an earlier one, and they are
   never sent to the engine, so do not smuggle them through `tc.env` or
   `tc.label`. Prefix the key with the module's name.
   **A module that starts several containers from one caller's block**
   (Go calls `Run` again with the caller's options for each, as etcd's
   cluster nodes) copies the request with `tc.request_copy(r)` before adding
   what is particular to the first container, and runs a fresh copy of that
   for each further one (`modules/etcd`). The copy has every setting, list
   and module setting; closures and the wait strategy are shared. A request
   handed to `tc.run_request` is the container's, so copy before, not after.
3. **Accessors** (`ConnectionString`, `MustConnectionString`) take the
   container and use `tc.host`, `tc.mapped_port`, `tc.endpoint`, `tc.exec`.
   No `Must*`: return `(value, err)`.
4. **The test** is `tests/test_<name>.ae` (std.spec), starts the real image
   against the engine, skips when there is none
   (`testing.skip_if_no_engine(fw)`), and checks the service for real over the
   mapped port, not just that it started. Tests are **representative, not
   exhaustive**: where the service has an HTTP/REST interface (vault,
   consul, registry, couchdb, ...) exercise that interface with
   std.http.client (servirtium-vcr's pre-recorded suites cover the HTTP
   ones); for a pure wire-protocol service (MQTT, AMQP, LDAP, MySQL, ...)
   one representative check is enough (a handshake, one round trip with
   std.tcp / std.resp, or the service's own CLI through `tc.exec`). An
   option gets the one assertion that shows it took effect. It ends every container it starts (`testing.cleanup_container(c)`
   with `spec.after_each() callback { testing.cleanup_all() }`). Port the Go
   test cases by name (`TestRedisWithLogLevel` -> an `it` that says so).
   Keep images small and pinned to the tag the Go test uses or an `-alpine`
   one.
5. Copy the module's `testdata/` files the tests need from the Go module.
6. Update the module's row in `PORTING.md`, and list what is not ported (and
   why) in the module's header comment.
7. Language traps met so far: `state`, `message`, `reply`, `make` and `send`
   are keywords; `string.concat(null, x)` is `""` (a `heap.new` struct's string
   fields start null: initialize them); `string.substring` stops at a NUL
   (use `string.string_substring_n` on binary data); `tcp.write` takes a C
   string (use `tcp.write_all(sock, string.bytes(s))` for binary);
   fluent `spec.expect_*` chains do not resolve inside a helper function
   (use the flat `spec.assert_*`). Text to embed verbatim (a shell script,
   SQL, a config file Go embeds) goes in a heredoc, `const S = <<SH` ...
   `SH` on its own line: no `${}` interpolation, no escapes, but the newline
   before the closing marker is dropped (`modules/mongodb`).

## 10. Deliberately different from Go

| Go | Here | Why |
|---|---|---|
| Functional options `...ContainerCustomizer` | A builder block of setters | Aether's idiom for configuration, and what `std.sandbox` does. |
| `context.Context` everywhere | Timeouts are `Duration`s on the thing that waits | No contexts in Aether; a deadline is all Go's code uses them for here. |
| `error` values, `errors.Is` | `string` errors (`""` is success), `docker.is_not_found(err)` etc. classify engine errors by status | std's convention throughout. |
| `wait.StrategyTarget` interface | `*docker.Container` | No interfaces; one concrete target is all the core has. |
| Goroutines for `ForAny`, log production | Interleaved probes; `std.worker` threads | Section 3, 6. |
| `io.Reader` results (logs, exec, copy-from) | Whole `string`s (binary-safe) | Test outputs are small; a streaming reader is `docker.stream_*` for the rare caller that needs one (events, followed logs). |
| `Container` interface with a Docker implementation | One `docker.Container` struct | Only the Docker Engine API exists here (Docker and Podman both speak it). |
| `ProviderType`, `RuntimeProvider` registry | Podman detected from the engine itself | The registry exists in Go to configure Podman; the engine says what it is. |
| Docker Compose (compose-go / docker/compose as libraries) | `modules/compose` drives the compose CLI (section 11) | The libraries are Go; the CLI is the same code, already built. |
| `tls.Config` in `WithTLS`, `TLSStrategy.TLSConfig()` | A CA file, or no verification; the PEMs read back | std.http.client's TLS knobs (section 3). |
| `wait.ForSQL` over `database/sql` | `wait.for_sql` over this repository's `sql` (section 14) | Aether's std has no SQL layer; `sql/` is one, to be teased out into its own package. |
| Port forwarding (`HostAccessPorts`) through an SSH-tunnel sidecar (`testcontainers/sshd`) | The engine's `host-gateway` extra host | Section 12: no SSH client in Aether, and the engines do it themselves. |

## 11. Compose

`modules/compose` is Go's `ComposeStack` API implemented the way Go's
`compose_local.go` works: by running the compose command line. Go's main
flavour (`compose.go` / `compose_api.go`) links compose-spec/compose-go and
docker/compose as Go libraries; those have no Aether counterpart and are
not ported.

```aether
import modules.compose

stack, err = compose.new_stack() {          // Go's NewDockerComposeWith
    file("testdata/docker-compose.yml")     // WithStackFiles; content(text) is WithStackReaders
    identifier("myproject")                 // StackIdentifier; default a random uuid
    profile("dev")                          // WithProfiles
    env("bar", "BAR")                       // WithEnv
    wait_for_service("nginx", wait.for_listening_port("80/tcp"))
}
err = compose.up(stack) { wait_running(); remove_orphans() }   // up -d --wait --remove-orphans
c, _ = compose.service_container(stack, "nginx")              // *docker.Container
err = compose.down(stack) { remove_orphans(); remove_volumes(); remove_images("local") }
```

- **Shape.** The stack is a builder, like `tc.run`, because Go's stack is
  configured by options and then used; `up` and `down` are builders too,
  their blocks Go's `StackUpOption` / `StackDownOption` lists, sharing one
  `Options` struct (so `remove_orphans()` works in either block). Setters
  also take the stack or options pointer first, which is how the test
  checks the command lines (`command_line`, `up_args`, `down_args`) without
  running anything.
- **The CLI** is `cli([...])`, else `TESTCONTAINERS_COMPOSE_COMMAND`, else
  the first of `docker compose` (the plugin answers `compose version`),
  `docker-compose`, `podman compose`, `podman-compose` on `PATH`. Files go
  as absolute `-f`s, the project as `-p`, profiles as `--profile`; env is
  added to this process's environment through `/usr/bin/env`. A docker CLI
  gets the core's engine as `DOCKER_HOST` when nothing else sets one.
- **Waits.** As in Go, `up` does not leave readiness to compose: after
  `up -d` it finds each waited service's container by compose's labels
  (`com.docker.compose.project` / `.service`) through the Engine API and runs
  the strategy with `wait.until_ready`, one service after another.
  `service_container` is that lookup, so `tc.endpoint`, `tc.exec`,
  `tc.logs` work on a service.
- **The reaper.** Go stamps the session labels on the project it loaded.
  The CLI cannot be given labels, but it can be given one more file: `up`
  starts the reaper (`tc.reaper_start`) and adds an override that labels
  every service, the default and every declared network, and every
  non-external volume with the session (and `reap=true`). Images compose
  builds are not labelled.
- **services()** reads the files with `testcontainers.miniyaml`, a
  pure-Aether reader of the compose YAML subset (std.yaml needs libfyaml,
  which the released Aether toolchains, macOS and Linux alike, are built
  without, so it returns "unavailable" however many libfyaml packages are
  installed); merged, filtered by profile, `"*"` for all); interpolated or `extends`-made names are not
  resolved, where Go's loader would.


## 12. Reaching the test's host (`HostAccessPorts`)

```aether
server = http.server_create(0)            // anything listening on the host
...
c, err = tc.run("alpine:3") {
    host_access_port(port)                // Go's WithHostPortAccess(port)
    cmd(["sleep", "300"])
}
tc.exec(c, ["wget", "-qO-", "http://${tc.HOST_INTERNAL}:${port}/"])   // host.testcontainers.internal
```

Go starts a `testcontainers/sshd` sidecar, opens an SSH connection to it
from the test process with a reverse tunnel per port, and points
`host.testcontainers.internal` at the sidecar. Aether has no SSH client,
and both engines can do it without one: the first `host_access_port` adds
the extra host `host.testcontainers.internal:host-gateway`, and Docker
(20.10 on) and Podman resolve `host-gateway` to the host they run for.
Where that address lands differs per engine, which decides where the host
service must listen:

| Engine | `host-gateway` is | A service on `127.0.0.1` |
|---|---|---|
| Podman machine (macOS, Windows) | gvproxy's host address, forwarded to the host's loopback | reached |
| Docker Desktop, OrbStack, Colima | the VM's host address, forwarded to the host's loopback | reached |
| Docker on Linux | the bridge's gateway (`docker0`, 172.17.0.1) | not reached: listen on `0.0.0.0` or the bridge address |
| rootless Podman on Linux | pasta's gateway (169.254.1.2 on Podman 6.1.4), which reaches the host's interfaces, not its loopback | not reached ("Connection refused"): listen on `0.0.0.0` |

`tests/test_host_access.ae` binds `0.0.0.0` on a kernel-picked port, the
one choice that works on every row (verified on a Podman machine on macOS
and on rootless Podman 6.1.4 on Linux; the Docker on Linux row is from
Docker's documented `host-gateway` behaviour, not run here). A service on
`0.0.0.0` is reachable from the LAN, so bind it only for the test's
lifetime. Go does not have this constraint: its sshd sidecar's reverse
tunnel is dialled from the test process to `localhost:<port>`, so a
loopback-only listener works with any engine there. This port trades that
for not needing an SSH client.

The ports are kept on the request (Go's `HostAccessPorts`) but nothing is
tunnelled, so any port on the host is reachable, not only those named.

## 13. Reusing a container (`WithReuseByName`)

```aether
c, err = tc.run("postgres:16-alpine") {
    reuse_by_name("orders-db")     // Go's WithReuseByName("orders-db")
    ...
}
```

As Go's `ReuseOrCreateContainer`: the container called `orders-db` is
looked up by name (`GET /containers/orders-db/json`); if it exists it is
returned, started first when it is stopped (a paused one is an error), and
the request's post-start steps run on it (hooks, startup commands, log
consumers, the wait), as Go's `startedHook` does; if not, it is created
under the name and started. A 409 from create (another process made it at
the same moment) waits for that one. One reuse runs at a time in a process
(Go's `reuseContainerMx`). An empty name is an error.

The reaper. Go labels a reused container like any other, so the session's
Ryuk removes it when the process ends: reuse works within a run, and across
runs only with Ryuk off. testcontainers-go at 55f58feb has no
`testcontainers.reuse.enable` switch (that is testcontainers-java's); here
it decides the reaper's part: with `testcontainers.reuse.enable=true` in
`~/.testcontainers.properties` or `TESTCONTAINERS_REUSE_ENABLE=true`, a
container created for reuse carries `org.testcontainers.reap=false`, which
the reaper's filter does not match, so it outlives the run and the next run
finds it. Remove it yourself (`tc.terminate`, or
`podman rm -f orders-db`) when done with it. Without the switch, Go's
behaviour.


## 14. `sql`: a `database/sql` for Aether

`wait/sql.go` needs a SQL client, and Aether's std has none, so this
repository carries one: `sql/`, a `database/sql`-shaped interface, and two
drivers: `sql/postgres/`, PostgreSQL, ported from jackc/pgx v5.9.2, and
`sql/mysql/`, MySQL and MariaDB, ported from go-sql-driver/mysql v1.9.3
(`sql/README.md` has the usage; `sql/NOTICE` what came from where). It
lives here while testcontainers' integration tests drive it toward
completion; it is meant to be teased out into a package of its own later,
with pure Aether unit tests of its own (`tests/test_sql_unit.ae`,
`tests/test_sql_postgres_unit.ae` and `tests/test_sql_mysql_unit.ae` are
those, already engine-free). `sql/mysql/` keeps go-sql-driver's licence,
the MPL-2.0 (file-level copyleft: its files stay MPL, the rest of the
repository stays MIT); each ported file carries the MPL notice.

**The one-way rule.** Nothing under `sql/` imports `testcontainers` or
`modules`; testcontainers (`wait.for_sql`) and the tests import `sql`.
`tests/run.sh` refuses to run when the rule is broken, so the teasing out
is a move, not a rewrite.

**The shape**, Go's with Aether's errors (`(value, err)`, `""` success):

```aether
import sql
import sql.postgres as pgsql

pgsql.register()                                  // Go's `import _ "github.com/jackc/pgx/v5/stdlib"`
db, err = sql.open("pgx/v5", dsn)                 // sql.Open: no connection yet
err = sql.ping(db)
res, err = sql.exec(db, "UPDATE t SET n = $1 WHERE id = $2", [sql.int64(5), sql.text("a")])
n = sql.rows_affected(res)
rows, err = sql.query(db, "SELECT id, name FROM t", [])
while sql.next(rows) { id, _ = sql.int_at(rows, 0); name, _ = sql.string_at(rows, 1) }
sql.close_rows(rows)
row, err = sql.query_row(db, "SELECT count(*) FROM t", [])   // sql.ERR_NO_ROWS when none
st, err = sql.prepare(db, q)        ; sql.stmt_exec(st, args) ; sql.stmt_query(st, args) ; sql.stmt_close(st)
tx, err = sql.begin(db)             ; sql.tx_exec(tx, q, args) ; sql.tx_query(tx, q, args) ; sql.commit(tx) / sql.rollback(tx)
sql.close(db)
```

Arguments are an array of `sql.Value` (`text`, `int64`, `float64`,
`boolean`, `blob`, `null_value`), positional, in the database's own
placeholder syntax (`$1` for PostgreSQL, `?` for MySQL); a column is read
with `string_at`, `int_at`, `float_at`, `bool_at`, `bytes_at` (each
`(value, err)`, converting as `database/sql`'s `convertAssign` does and
failing on NULL as Go does), `is_null_at`, `column_names`, `column_types`.
`sql.sqlstate(err)` takes the SQLSTATE out of a driver's error (pgx's
`(SQLSTATE 28P01)` and go-sql-driver's `Error 1045 (28000): ...`).

**Drivers.** Aether has neither interfaces nor import-time `init`, so a
driver is a `*sql.Driver`, a struct of function pointers (connect, close,
ping, exec, query, prepare, stmt_exec, stmt_query, stmt_close, begin,
commit, rollback, is_bad) built with `sql.new_driver(name)` (which stubs
the optional ones) and registered with `sql.register(name, d)` by a
`register()` function of the driver module that the program calls once
(idempotent). Every function returns its error as a string and writes
what it produced into the sql-owned struct it is handed (`*sql.Conn`,
`*sql.Result`, `*sql.Rows` through `rows_set_columns`/`rows_append`,
`*sql.Stmt`), so the vtable carries no tuples. `struct Driver` in
`sql/module.ae` documents each field's contract; `sql/postgres/module.ae`
is the model and `sql/mysql/module.ae` the second: the protocol's bytes in
`mysqlproto` (pure functions, unit-tested), one connection in `mysqlconn`
(with a mock transport the Go tests' captured exchanges replay over), the
vtable in the driver, which turns a statement with arguments into
prepare, execute, close as `database/sql` does on Go's `driver.ErrSkip`.

**One connection, shaped for a pool.** A `*DB` makes its connection on
first use and makes it again after the driver reports it broken (Go's
`driver.ErrBadConn`); a prepared statement is prepared again on the new
connection, as Go's is on another pool connection. With one connection, a
`*DB` is for one thread, and while a `Tx` is open the DB's own calls refuse
rather than run inside it. A pool replaces `DB.conn` without changing the
API. Rows are read whole by the driver (no streaming cursor yet).

## 15. Servirtium in the middle: moved to servirtium-vcr

The Servirtium recorder (formerly `testcontainers.servirtium`) and the
suites and tapes it recorded moved to servirtium-vcr's
`pre-recorded/from-testcontainers/` on 2026-11-07. Recordings depend on
this package; this package does not depend on Servirtium.

