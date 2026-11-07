# Porting status

From testcontainers-go at commit 55f58feb. A Go file is **ported** when its
behaviour is here, **partial** when some of it is (the rest named), **not
ported** with the reason. Test files (`*_test.go`) are ported as the tests
in `tests/` that name them in their first line.

## Core

| Go file | Aether file | Status | Notes |
|---|---|---|---|
| `testcontainers.go` | `testcontainers/module.ae` | ported | Session id, `SessionID()`. |
| `container.go` | `testcontainers/module.ae`, `testcontainers/docker/module.ae` | ported | `ContainerRequest` is `tc.Request` filled by setters; the `Container` interface is `docker.Container` and the `tc.*` operations. `FromDockerfile` ported; deprecated fields kept as setters (DESIGN.md). |
| `generic.go` | `testcontainers/module.ae` (`run`, `create`), `testcontainers/network/module.ae` | ported | `Run`, `GenericContainer` (`Started: false` is `create`), `GenericNetwork`, `GenericLabels`. |
| `options.go` | `testcontainers/module.ae` | ported | Every `With*` option is a setter (`WithHostPortAccess` is `host_access_port`). |
| `docker.go` | `testcontainers/docker/module.ae`, `testcontainers/module.ae` | ported | Create, start, stop, terminate, inspect, state, ports, endpoints, exec, copy to and from, logs, log production, networks of a container. `DockerProvider` collapses into the client. |
| `docker_client.go` | `testcontainers/docker/module.ae` | ported | The client with API negotiation and the `/info`-style calls; no client-side caching of `Info`. |
| `docker_auth.go` | `testcontainers/docker/module.ae` (`registry_auth`, `registry_auth_lookup`, `credential_helper_get`) | ported | `DOCKER_AUTH_CONFIG`, else `config.json` in `$DOCKER_CONFIG` or `~/.docker`: `auths` entries (auth, username/password, identity token), matched by key or by the key's host; and, for an `auths` entry with no credentials or a `credHelpers` entry, `docker-credential-<helper> get` (`credHelpers[key]`, else `credsStore`) with the server on stdin, `<token>` as an identity token. No credentials cache (Go caches per process). A helper's failure fails the pull. A pull from a loopback registry on Podman goes through libpod's pull with `tlsVerify=false` (Docker's default for loopback). `tests/test_docker_auth.ae`. |
| `docker_mounts.go`, `mounts.go` | `testcontainers/module.ae` (`bind`, `bind_ro`, `volume`, `tmpfs`) | ported | Bind, volume and tmpfs mounts; volumes are created first with the session labels. Image mounts (`WithImageMount`) not ported. |
| `file.go` | `testcontainers/docker/module.ae` | ported | Tar of a file or a directory with std.tar, `PUT /archive`. |
| `image.go` | `testcontainers/docker/module.ae`, `testcontainers/module.ae` | ported | `ImageSubstitutor` is a closure; the hub-prefix substitutor is `docker.hub_prefixed`. `SaveImages` not ported. |
| `lifecycle.go` | `testcontainers/module.ae` | ported | All eleven hooks, Go's order (pre: default then the caller's; post: the caller's then default). |
| `logconsumer.go` | `testcontainers/module.ae` (`log_consumer`, `logs_follow`) | ported | Consumers on a `std.worker` thread. |
| `network.go` | `testcontainers/docker/module.ae` | ported | |
| `network/network.go` | `testcontainers/network/module.ae` | ported | `New`, `WithDriver`, `WithInternal`, `WithAttachable`, `WithLabels`, `WithIPAM` (subnet, gateway), `WithEnableIPv6`; `WithNetwork` / `WithNetworkName` are the core's `with_network` / `network_alias`. |
| `reaper.go` | `testcontainers/module.ae` | ported | Ryuk 0.14.0, lookup of a session's running reaper, the label filter handshake, privileged and the in-engine socket on Podman. |
| `cleanup.go` | `testcontainers/module.ae` (`terminate`, `terminate_graceful`) | ported | `TerminateContainer` and its stop timeout option. |
| `testing.go` | `testcontainers/testing/module.ae` | ported | `SkipIfProviderIsNotHealthy`, `SkipIfDockerDesktop`, `CleanupContainer`, `CleanupNetwork`, `RequireContainerExec`, for std.spec. |
| `config.go`, `internal/config/config.go` | `testcontainers/docker/module.ae` (`Config`, `config`) | ported | Properties file and environment, Go's precedence. |
| `internal/core/docker_host.go` | `testcontainers/docker/module.ae` (`client`, `candidates`) | ported | Go's order, plus Podman, OrbStack and Colima sockets; no docker CLI contexts (Go reads none either). |
| `internal/core/docker_rootless.go` | `testcontainers/docker/module.ae` (`candidates`) | ported | |
| `internal/core/docker_socket.go` | `testcontainers/docker/module.ae` (`engine_socket_for_mounts`) | ported | Plus Podman's own `host.remoteSocket.path`. |
| `internal/core/client.go` | `testcontainers/docker/module.ae` (`new_client`) | ported | |
| `internal/core/labels.go` | `testcontainers/docker/module.ae` | ported | `org.testcontainers.lang=aether`. |
| `internal/core/images.go` | `testcontainers/docker/module.ae` (`parse_image`, `image_registry`) | ported | |
| `internal/core/runtime_provider.go`, `runtime_provider.go` | `testcontainers/docker/module.ae` | partial | No provider registry: Podman is detected from the engine (`/version`, `Libpod-Api-Version`) or `provider=podman`. |
| `internal/core/bootstrap/bootstrap.go` | `testcontainers/docker/module.ae` (`session_id`) | partial | A random id per process instead of a hash of the process. |
| `internal/core/network/network.go` | `testcontainers/docker/module.ae` | ported | The default bridge network per engine. |
| `internal/version.go` | `testcontainers/docker/module.ae` (`VERSION`) | ported | |
| `provider.go` | `testcontainers/docker/module.ae` | partial | One provider (the Engine API); `ProviderType` dropped. |
| `exec/processor.go` | `testcontainers/docker/module.ae` (`exec`, `exec_with`) | ported | `Multiplexed`, `WithUser`, `WithWorkingDir`, `WithEnv` are `exec_with`'s parameters and its split result. |
| `log/logger.go`, `logger_option.go` | | not ported | No logging layer: errors are returned, builds print with `print_build_log()`. |
| `wait/wait.go` | `testcontainers/wait/module.ae` | ported | `StrategyTarget` is `*docker.Container`. |
| `wait/log.go` | `testcontainers/wait/module.ae` | ported | Occurrence, regexp (std.regex). `Submatch` callback not ported. |
| `wait/host_port.go` | `testcontainers/wait/module.ae` | ported | Internal check (same shell command) and external dial. |
| `wait/http.go` | `testcontainers/wait/module.ae` | ported | Method, body, headers, basic auth, status and body matchers; TLS as `with_tls`, `with_allow_insecure`, `with_tls_ca_file`, `with_tls_config_from` (std.http.client takes a CA file or no verification, not a `tls.Config`: DESIGN.md section 3). Response-header matchers not ported. |
| `wait/health.go` | `testcontainers/wait/module.ae` | ported | |
| `wait/exec.go` | `testcontainers/wait/module.ae` | ported | |
| `wait/exit.go` | `testcontainers/wait/module.ae` | ported | |
| `wait/file.go` | `testcontainers/wait/module.ae` | ported | |
| `wait/all.go` | `testcontainers/wait/module.ae` | ported | |
| `wait/any.go` | `testcontainers/wait/module.ae` | ported | Interleaved probes instead of goroutines. |
| `wait/nop.go` | `testcontainers/wait/module.ae` (`for_nop`, `for_func`) | ported | |
| `wait/walk.go` | | not ported | Walking a strategy tree; `describe` covers the tree for messages. |
| `wait/errors.go`, `wait/errors_windows.go` | | not ported | Go's connection-refused classification; a dial here just retries. |
| `wait/sql.go` | `testcontainers/wait/module.ae` (`for_sql`, `with_query`) | ported | Over this repository's `sql` package (DESIGN.md section 14). Drivers: `postgres` / `pgx` / `pgx/v5` (`sql/postgres`, ported from jackc/pgx v5.9.2; register with `sql.postgres`'s `register()`) and `mysql` (`sql/mysql`, MySQL and MariaDB, ported from go-sql-driver/mysql v1.9.3, MPL-2.0; register with `sql.mysql`'s `register()`). Each poll opens a fresh connection (Go keeps one `sql.DB`). `tests/test_sql_unit.ae` (Go's `sql_test.go` cases without a container), `tests/test_sql_postgres.ae`, `tests/test_postgres.ae` (`TestContainerWithWaitForSQL`), `tests/test_cockroachdb.ae`, `tests/test_sql_mysql.ae` (MySQL 8.0.36 and MariaDB 12.3.2), `tests/test_mysql.ae` (`ExampleRun_connect`). |
| `wait/tls.go` | `testcontainers/wait/module.ae` (`for_tls_cert`, `for_tls_root_cas`, `with_root_cas`, `with_cert`, `with_server_name`, `tls_ca_file`, ...) | ported | The files are checked to be PEM, not parsed as X.509; the CA bundle is written to a host file for `with_tls_config_from`. No client certificates (std.http.client has none); `with_server_name` only for loopback names. Live in `tests/test_cockroachdb.ae` (secure /health verified against the CA, server name 127.0.0.1), servirtium-vcr's `pre-recorded/from-testcontainers/elasticsearch/test_elasticsearch.ae` (HTTPS wait verified against the container's CA) and servirtium-vcr `pre-recorded/from-testcontainers/fakegcsserver/test_fakegcsserver.ae` (with Servirtium recordings) (https, no verification). |
| `parallel.go` | `testcontainers/module.ae` (`container_request`, `parallel`) | ported | `ParallelContainers` as `tc.parallel(reqs, workers)` on `std.worker` threads (default 8 workers, Go's); containers and errors come back index-aligned, with Go's joined error. `tests/test_parallel.ae`. |
| `port_forwarding.go` | `testcontainers/module.ae` (`host_access_port`, `HOST_INTERNAL`) | ported, differently | `host.testcontainers.internal` through the engine's `host-gateway` extra host instead of an sshd sidecar with SSH reverse tunnels (no SSH client in Aether); DESIGN.md section 12 says where the host service must listen per engine. `tests/test_host_access.ae`. |
| `validator.go`, `generate.go` | | not ported | Go tooling. |
| `modules/compose` (core-side) | `modules/compose` | ported, through the CLI | See the compose row under Modules and DESIGN.md section 11. |
| (container reuse) `generic.go` `Reuse`, `docker.go` `ReuseOrCreateContainer`, `WithReuseByName` | `testcontainers/module.ae` (`reuse_by_name`), `testcontainers/docker/module.ae` (`find_container_by_name`) | ported | Plus `testcontainers.reuse.enable` / `TESTCONTAINERS_REUSE_ENABLE`, which keeps a reused container from the reaper so it outlives the run (DESIGN.md section 13). `tests/test_reuse.ae`. |

## Modules

Every module directory of testcontainers-go's `modules/` (88, with the
`azure` and `gcloud` families broken out). Status:

- **tested live**: the module is ported and its test (`tests/test_<name>.ae`,
  std.spec) starts the real image against an engine and talks to the
  service over its mapped port; it ran and passed against Podman 6.1.3 on
  an arm64 Mac (the last full run is at the end of this file).
- **compile-checked**: the module and the ported Go examples compile and
  the engine-free cases of the test run; the live case is skipped unless
  the variable named is set (or the engine named is used), for the reason
  given. The module's header comment says "compile-checked only".
- **not needed** / **not ported**: why.

A module port follows `modules/redis` (DESIGN.md section 9). Each module's
header comment lists what it leaves out; the deprecated `RunContainer` is
never ported and not listed. The note here is the part a test engineer
should know before reaching for it: images that differ from Go's, options
that take something else.

| Module | Status | Where, and what differs |
|---|---|---|
| activemq | tested live | `modules/activemq`, `tests/test_activemq.ae`. |
| aerospike | tested live | `modules/aerospike`, `tests/test_aerospike.ae`. |
| arangodb | tested live | `modules/arangodb`, `tests/test_arangodb.ae`. |
| artemis | tested live | `modules/artemis`, `tests/test_artemis.ae`. |
| azure | family, below | Go's `modules/azure` holds six modules; the old flat package is not ported. |
| azure/azurite | tested live | `modules/azurite`, servirtium-vcr `pre-recorded/from-testcontainers/azurite/test_azurite.ae` (with Servirtium recordings). Go's `modules/azurite` re-exports `modules/azure/azurite`; one port, `import modules.azurite`. |
| azure/cosmosdb | compile-checked (`TCAE_LIVE_COSMOSDB=1`) | `modules/azure/cosmosdb`, `tests/test_azure_cosmosdb.ae`. Alpha, no engine used to port it; not the azcosmos SDK examples. |
| azure/eventhubs | compile-checked (`TCAE_LIVE_EVENTHUBS=1`) | `modules/azure/eventhubs`, `tests/test_azure_eventhubs.ae`. With its Azurite and a typed config. |
| azure/lowkeyvault | compile-checked (`TCAE_LIVE_LOWKEYVAULT=1`) | `modules/azure/lowkeyvault`, `tests/test_azure_lowkeyvault.ae`.  |
| azure/servicebus | compile-checked (`TCAE_LIVE_SERVICEBUS=1`) | `modules/azure/servicebus`, `tests/test_azure_servicebus.ae`. With its SQL Server. |
| azure/sqledge | compile-checked (`TCAE_LIVE_SQLEDGE=1`) | `modules/azure/sqledge`, `tests/test_azure_sqledge.ae`.  |
| azurite | tested live | `modules/azurite`, servirtium-vcr `pre-recorded/from-testcontainers/azurite/test_azurite.ae` (with Servirtium recordings). |
| cassandra | tested live | `modules/cassandra`, `tests/test_cassandra.ae`. |
| chroma | tested live | `modules/chroma`, servirtium-vcr `pre-recorded/from-testcontainers/chroma/test_chroma.ae` (with Servirtium recordings). |
| clickhouse | tested live | `modules/clickhouse`, `tests/test_clickhouse.ae`. |
| cockroachdb | tested live | `modules/cockroachdb`, `tests/test_cockroachdb.ae`. The secure start waits with `wait.for_tls_cert` and HTTPS `/health` verified against the CA; the SQL ping is `wait.for_sql` (pgx/v5) as in Go: plain when insecure, TLS 1.3 `verify-full` against the container's CA with a password. A secure start without a password (root, Go's default) needs a client certificate, which the TLS client cannot present yet, so that one case pings with `cockroach sql` in the container. The test also queries through `sql` over TLS. |
| compose | compile-checked (`TCAE_LIVE_COMPOSE=1`) | `modules/compose`, `tests/test_compose.ae`. Go's `ComposeStack` through the compose CLI (DESIGN.md section 11); the engine-free cases (command lines, CLI discovery, services, profiles, the label override) run in every run, the cases that start a project only with the variable. Not the compose-go / docker/compose library flavour. |
| consul | tested live | `modules/consul`, servirtium-vcr `pre-recorded/from-testcontainers/consul/test_consul.ae` (with Servirtium recordings). Run, ApiEndpoint, WithConfigString, WithConfigFile; not the consul client used in Go's examples (the test uses the HTTP API). |
| couchbase | tested live | `modules/couchbase`, `tests/test_couchbase.ae`. |
| couchdb | tested live | `modules/couchdb`, servirtium-vcr `pre-recorded/from-testcontainers/couchdb/test_couchdb.ae` (with Servirtium recordings). The test uses the HTTP API. |
| cratedb | tested live | `modules/cratedb`, `tests/test_cratedb.ae`. |
| databend | tested live | `modules/databend`, `tests/test_databend.ae`. |
| dex | tested live | `modules/dex`, servirtium-vcr `pre-recorded/from-testcontainers/dex/test_dex.ae` (with Servirtium recordings). `user` takes a bcrypt **hash** of the password (no bcrypt in Aether's std; Go hashes at render time): make one with `htpasswd -bnBC 10 "" pw`. |
| dind | compile-checked (`TCAE_DIND=1`) | `modules/dind`, `tests/test_dind.ae`. Needs a privileged container with the host cgroup namespace; not run on the rootless Podman machine. |
| dockermcpgateway | tested live | `modules/dockermcpgateway`, `tests/test_dockermcpgateway.ae`. |
| dockermodelrunner | compile-checked (Docker Desktop only) | `modules/dockermodelrunner`, `tests/test_dockermodelrunner.ae`. Needs Docker Desktop's `model-runner.docker.internal`; the test skips on every other engine, as Go's does. |
| dolt | tested live | `modules/dolt`, `tests/test_dolt.ae`. |
| dynamodb | tested live | `modules/dynamodb`, servirtium-vcr `pre-recorded/from-testcontainers/dynamodb/test_dynamodb.ae` (with Servirtium recordings). |
| elasticsearch | tested live | `modules/elasticsearch`, servirtium-vcr `pre-recorded/from-testcontainers/elasticsearch/test_elasticsearch.ae` (with Servirtium recordings). 8.x secure start: the HTTP wait verifies against the CA read from the container (Go skips verification). |
| etcd | tested live | `modules/etcd`, `tests/test_etcd.ae`. With clusters: WithNodes, WithClusterToken, WithDataDir, WithAdditionalArgs, ClientEndpoint(s), PeerEndpoint(s), Terminate. The options are module settings (`tc.set_setting`); further cluster nodes run from `tc.request_copy` of the caller's request, so they get the caller's options as in Go. `additional_args` appends on every call (Go keeps the last call's); fewer than two `nodes` means one node. Not the etcd client of Go's examples (the test uses the v3 JSON gateway and etcdctl). |
| fakegcsserver | tested live | `modules/fakegcsserver`, servirtium-vcr `pre-recorded/from-testcontainers/fakegcsserver/test_fakegcsserver.ae` (with Servirtium recordings). `scheme("https")` waits over HTTPS without verification, as Go. |
| firebird | tested live | `modules/firebird`, `tests/test_firebird.ae`. |
| forgejo | tested live | `modules/forgejo`, servirtium-vcr `pre-recorded/from-testcontainers/forgejo/test_forgejo.ae` (with Servirtium recordings). |
| garage | tested live | `modules/garage`, servirtium-vcr `pre-recorded/from-testcontainers/garage/test_garage.ae` (with Servirtium recordings). |
| gcloud | family, below | Go's `modules/gcloud` holds six emulators; its deprecated flat `RunBigQuery` ... functions (`gcloud.go` and friends) are not ported. |
| gcloud/bigquery | tested live | `modules/gcloud/bigquery`, servirtium-vcr `pre-recorded/from-testcontainers/gcloud_bigquery/test_gcloud_bigquery.ae` (with Servirtium recordings). |
| gcloud/bigtable | compile-checked (`TCAE_LIVE_BIGTABLE=1`) | `modules/gcloud/bigtable`, `tests/test_gcloud_bigtable.ae`. Alpha, no engine used to port it. |
| gcloud/datastore | tested live | `modules/gcloud/datastore`, servirtium-vcr `pre-recorded/from-testcontainers/gcloud_datastore/test_gcloud_datastore.ae` (with Servirtium recordings). |
| gcloud/firestore | tested live | `modules/gcloud/firestore`, servirtium-vcr `pre-recorded/from-testcontainers/gcloud_firestore/test_gcloud_firestore.ae` (with Servirtium recordings). |
| gcloud/pubsub | tested live | `modules/gcloud/pubsub`, servirtium-vcr `pre-recorded/from-testcontainers/gcloud_pubsub/test_gcloud_pubsub.ae` (with Servirtium recordings). |
| gcloud/spanner | compile-checked (`TCAE_LIVE_SPANNER=1`) | `modules/gcloud/spanner`, `tests/test_gcloud_spanner.ae`. Alpha, no engine used to port it. |
| grafana-lgtm | tested live | `modules/grafana_lgtm`, servirtium-vcr `pre-recorded/from-testcontainers/grafana_lgtm/test_grafana_lgtm.ae` (with Servirtium recordings). `modules/grafana_lgtm` (`import modules.grafana_lgtm`): an Aether module path cannot have a `-`. |
| inbucket | tested live | `modules/inbucket`, servirtium-vcr `pre-recorded/from-testcontainers/inbucket/test_inbucket.ae` (with Servirtium recordings). |
| influxdb | tested live | `modules/influxdb`, `tests/test_influxdb.ae`. |
| k3s | compile-checked (`TCAE_K3S=1`) | `modules/k3s`, `tests/test_k3s.ae`. Needs a privileged container. |
| k6 | tested live | `modules/k6`, `tests/test_k6.ae`. Go's default `szkiba/k6x:v0.3.1` no longer works (it fetches k6's extension catalog from a GitHub path that 404s, exit 116); the test runs the official `grafana/k6:1.0.0`, same arguments. `WithRemoteTestScript` not ported (download the script and pass it to `test_script`). |
| kafka | tested live | `modules/kafka`, `tests/test_kafka.ae`. |
| kurrentdb | tested live | `modules/kurrentdb`, `tests/test_kurrentdb.ae`. |
| localstack | tested live | `modules/localstack`, servirtium-vcr `pre-recorded/from-testcontainers/localstack/test_localstack.ae` (with Servirtium recordings). |
| mailpit | tested live | `modules/mailpit`, servirtium-vcr `pre-recorded/from-testcontainers/mailpit/test_mailpit.ae` (with Servirtium recordings). `run` returns the `*docker.Container` and the helpers take it. |
| mariadb | tested live | `modules/mariadb`, `tests/test_mariadb.ae`. Run, ConnectionString, WithDatabase/Username/Password, WithScripts, WithConfigFile, WithDefaultCredentials, the MYSQL_* mirroring of every MARIADB_* variable; not MustConnectionString. The connection string works with `sql.mysql` and `wait.for_sql` (`tests/test_sql_mysql.ae` runs against MariaDB 12.3.2). |
| meilisearch | tested live | `modules/meilisearch`, servirtium-vcr `pre-recorded/from-testcontainers/meilisearch/test_meilisearch.ae` (with Servirtium recordings). WithDumpImport's file copy and import command are one setter. |
| memcached | tested live | `modules/memcached`, `tests/test_memcached.ae`. |
| milvus | tested live | `modules/milvus`, servirtium-vcr `pre-recorded/from-testcontainers/milvus/test_milvus.ae` (with Servirtium recordings). |
| minio | tested live | `modules/minio`, servirtium-vcr `pre-recorded/from-testcontainers/minio/test_minio.ae` (with Servirtium recordings). Go's default image (`quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z`) can no longer be pulled (quay.io and Docker Hub refuse it as of 2026-11); the test runs `cgr.dev/chainguard/minio:latest`, which takes the same command. S3 calls signed with SigV4 by the test (no minio-go). |
| mockserver | tested live | `modules/mockserver`, servirtium-vcr `pre-recorded/from-testcontainers/mockserver/test_mockserver.ae` (with Servirtium recordings). Through the REST API (mock-server-client-go is not ported). |
| mongodb | tested live | `modules/mongodb`, `tests/test_mongodb.ae`. Run, ConnectionString, WithUsername/Password, WithReplicaSet (with auth: Go's entrypoint-tc.sh verbatim, the key file, rs.initiate). `connection_string` does not percent-encode the credentials; not the atlaslocal sub-module. The test speaks OP_MSG to the mapped port. |
| mosquitto | tested live | `modules/mosquitto`, `tests/test_mosquitto.ae`. Returns the plain `*docker.Container` (Go's wrapper type stores nothing). |
| mssql | tested live | `modules/mssql`, `tests/test_mssql.ae`. |
| mysql | tested live | `modules/mysql`, `tests/test_mysql.ae`. Run, ConnectionString, WithDatabase/Username/Password, WithScripts, WithConfigFile, WithDefaultCredentials, ExampleRun_connect (through `sql.mysql`, waiting with `wait.for_sql`); not MustConnectionString. |
| nats | tested live | `modules/nats`, `tests/test_nats.ae`. Go's argument options are setters on the same request. |
| nebulagraph | tested live | `modules/nebulagraph`, `tests/test_nebulagraph.ae`. |
| neo4j | tested live | `modules/neo4j`, `tests/test_neo4j.ae`. |
| nginx | tested live | `modules/nginx`, servirtium-vcr `pre-recorded/from-testcontainers/nginx/test_nginx.ae` (with Servirtium recordings). Returns the plain `*docker.Container` (Go's wrapper type stores nothing). |
| ollama | tested live | `modules/ollama`, `tests/test_ollama.ae`. |
| openfga | tested live | `modules/openfga`, servirtium-vcr `pre-recorded/from-testcontainers/openfga/test_openfga.ae` (with Servirtium recordings). |
| openldap | tested live | `modules/openldap`, `tests/test_openldap.ae`. The credentials are read from the request rather than Inspect, `initial_ldif` runs ldapadd with the container's own env; not the go-ldap examples (the test binds with a hand-built BER BindRequest). |
| opensearch | tested live | `modules/opensearch`, servirtium-vcr `pre-recorded/from-testcontainers/opensearch/test_opensearch.ae` (with Servirtium recordings). |
| orientdb | tested live | `modules/orientdb`, `tests/test_orientdb.ae`. |
| papercutsmtp | tested live | `modules/papercutsmtp`, servirtium-vcr `pre-recorded/from-testcontainers/papercutsmtp/test_papercutsmtp.ae` (with Servirtium recordings). |
| pinecone | tested live | `modules/pinecone`, servirtium-vcr `pre-recorded/from-testcontainers/pinecone/test_pinecone.ae` (with Servirtium recordings). |
| podman | not needed | In Go it registers Podman as a runtime provider; here the engine is detected as Podman (DESIGN.md section 8). |
| postgres | tested live | `modules/postgres`, `tests/test_postgres.ae` (with `TestContainerWithWaitForSQL` through `wait.for_sql`) and `tests/test_sql_postgres.ae`. Not `WithSQLDriver` (Snapshot/Restore keep using psql in the container), `WithSSLCert`. |
| presto | tested live | `modules/presto`, `tests/test_presto.ae`. |
| pulsar | tested live | `modules/pulsar`, `tests/test_pulsar.ae`. |
| qdrant | tested live | `modules/qdrant`, servirtium-vcr `pre-recorded/from-testcontainers/qdrant/test_qdrant.ae` (with Servirtium recordings). |
| questdb | tested live | `modules/questdb`, `tests/test_questdb.ae`. Go's test image `questdb/questdb:7.4.2` is amd64 only; the test runs `questdb/questdb:9.0.0` (arm64 here). Not the pgx / influxdb clients. |
| rabbitmq | tested live | `modules/rabbitmq`, `tests/test_rabbitmq.ae`. Run, AmqpURL, AmqpsURL, HttpURL, HttpsURL, WithAdminUsername/Password, WithSSL (the config fragment is a module setting; the node config is built with interpolation instead of text/template; the verification mode is a string). |
| ravendb | tested live | `modules/ravendb`, `tests/test_ravendb.ae`. |
| redis | tested live | `modules/redis`, `tests/test_redis.ae`. Not `WithTLS` (needs run-time certificates). |
| redpanda | tested live | `modules/redpanda`, `tests/test_redpanda.ae`. |
| registry | tested live | `modules/registry`, servirtium-vcr `pre-recorded/from-testcontainers/registry/test_registry.ae` (with Servirtium recordings). Credentials as a user / password pair on image_exists, delete_image, push_image, else the Docker config and its credential helpers; not `SetDockerAuthConfig` / `DockerAuthConfig`, nor Go's platform matching in `PullImage`. |
| s3mock | tested live | `modules/s3mock`, servirtium-vcr `pre-recorded/from-testcontainers/s3mock/test_s3mock.ae` (with Servirtium recordings). |
| sbx | not ported | Drives Docker's `sbx` CLI and Docker Sandboxes (a microVM per container with its own Docker engine), which are not released and not available on this Mac; nothing to port against or test. |
| scylladb | tested live | `modules/scylladb`, `tests/test_scylladb.ae`. |
| sftp | tested live | `modules/sftp`, `tests/test_sftp.ae`. The test checks the SSH banner on the mapped port and the configured users inside the container (no SSH client in Aether's std, so not Go's x/crypto/ssh + pkg/sftp session). |
| socat | tested live | `modules/socat`, `tests/test_socat.ae`. |
| solace | compile-checked (skipped on Podman) | `modules/solace`, `tests/test_solace.ae`. Rootless Podman refuses the `nofile` ulimit 1048576 Solace needs (crun setrlimit). |
| solr | tested live | `modules/solr`, servirtium-vcr `pre-recorded/from-testcontainers/solr/test_solr.ae` (with Servirtium recordings). |
| surrealdb | tested live | `modules/surrealdb`, `tests/test_surrealdb.ae`. Not the examples module (Go SurrealDB SDK). |
| tidb | tested live | `modules/tidb`, `tests/test_tidb.ae`. |
| timeplus | tested live | `modules/timeplus`, `tests/test_timeplus.ae`. |
| toxiproxy | tested live | `modules/toxiproxy`, servirtium-vcr `pre-recorded/from-testcontainers/toxiproxy/test_toxiproxy.ae` (with Servirtium recordings). |
| trino | tested live | `modules/trino`, `tests/test_trino.ae`. |
| typesense | tested live | `modules/typesense`, servirtium-vcr `pre-recorded/from-testcontainers/typesense/test_typesense.ae` (with Servirtium recordings). |
| valkey | tested live | `modules/valkey`, `tests/test_valkey.ae`. Not `WithTLS` / `TLSConfig` (run-time certificates). |
| vault | tested live | `modules/vault`, servirtium-vcr `pre-recorded/from-testcontainers/vault/test_vault.ae` (with Servirtium recordings). Not the vault-client-go examples (the test calls the HTTP API and the CLI). |
| vearch | tested live | `modules/vearch`, servirtium-vcr `pre-recorded/from-testcontainers/vearch/test_vearch.ae` (with Servirtium recordings). |
| weaviate | tested live | `modules/weaviate`, servirtium-vcr `pre-recorded/from-testcontainers/weaviate/test_weaviate.ae` (with Servirtium recordings). |
| yugabytedb | compile-checked (`TCAE_YUGABYTEDB=1`) | `modules/yugabytedb`, `tests/test_yugabytedb.ae`. On the Podman machine the container was killed (exit 137) while yugabyted was starting. |

### Deviations from Go a test engineer meets

- **Images Go names that no longer work**: minio's default
  (`quay.io/minio/minio:RELEASE.2024-01-16T16-07-38Z`, no longer pullable;
  use `cgr.dev/chainguard/minio`), k6's default `szkiba/k6x:v0.3.1` (its
  extension catalog 404s; use `grafana/k6`). The modules keep Go's
  `DEFAULT_IMAGE`; the tests run the replacements.
- **Images without arm64**: questdb's `7.4.2` (the test runs `9.0.0`).
- **dex** `user(...)` takes a bcrypt hash, not the password (no bcrypt in
  Aether's std).
- **Module paths**: a Go directory with `-` has `_` here
  (`grafana-lgtm` is `modules/grafana_lgtm`); the families are
  `modules/azure/<name>` and `modules/gcloud/<name>`, imported as
  `import modules.azure.cosmosdb`.
- **SQL clients**: `sql` (DESIGN.md section 14) has one driver so far,
  PostgreSQL (`sql/postgres`, a port of pgx), which `wait.for_sql` and the
  postgres and cockroachdb tests use. Modules of other databases that Go
  waits on with `wait.ForSQL` or hands a `database/sql` handle from (mysql,
  mariadb, mssql, clickhouse, ...) still wait with `wait.for_exec` on the
  image's own client and return connection strings, and examples that open
  a SQL connection to them are not ported, until their drivers exist (MySQL
  is next).
- **No client libraries**: where Go's examples use a service's Go SDK
  (Kafka, MongoDB, Elasticsearch, cloud SDKs), the tests speak the
  service's HTTP API or wire protocol directly, or use its CLI in the
  container.

## sql/ (not part of testcontainers-go)

The `sql` package and its drivers are ports of other projects, listed in
`sql/NOTICE`:

| Source | Aether file | Status | Notes |
|---|---|---|---|
| Go's `database/sql` (the shape only) | `sql/module.ae` | designed to it | Open/Ping/Exec/Query/QueryRow/Prepare/Begin, Rows, Stmt, Tx, registration by name. One connection per DB (no pool), rows read whole, accessors for string/int/float/bool/bytes/NULL. |
| pgx `pgproto3/` | `sql/postgres/pgproto3/module.ae` | partial | Every frontend message the driver sends and every backend message but COPY and FunctionCall; protocol 3.0. |
| pgx `pgconn/` (`config.go`, `defaults.go`, `pgconn.go`, `auth_scram.go`, `errors.go`) | `sql/postgres/pgconn/module.ae` | partial | ParseConfig (URL, keyword/value, PG* env, hosts and fallbacks, sslmode), cleartext/MD5/SCRAM-SHA-256, simple and extended protocol, Prepare/Deallocate, TLS 1.3 by SSLRequest. Not: .pgpass, service files, client certificates, channel binding, GSS, pipelines, COPY, cancel, protocol 3.2; TLS always verifies (see `sql/README.md`). |
| pgx `stdlib/sql.go`, `tx.go`, `pgtype/` (text format) | `sql/postgres/module.ae` | partial | The database/sql driver, ErrTxCommitRollback, type names, bytea; no binary format. |
| pgx tests | `tests/test_sql_postgres_unit.ae` | partial | `pgproto3` frontend/backend/bind tests, `auth_scram_test.go`, `config_test.go` cases, plus RFC 7677's SCRAM vector. |

## Last full run

2026-11-05, `sh tests/run.sh` (one file at a time, images removed as it
went), ae 0.885.0 dev tree with Unix sockets, Podman 6.1.3 machine on an
arm64 Mac: 105 passed, 0 failed, 105 total; 82 pulled images removed;
nothing left running. The compile-checked modules' files pass by running
their engine-free cases and skipping the live ones.
