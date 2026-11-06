# sql

A `database/sql` for Aether: one interface (`import sql`) and drivers
registered by name. Two drivers so far: PostgreSQL (`import sql.postgres`),
ported from [jackc/pgx](https://github.com/jackc/pgx) v5.9.2, and MySQL
and MariaDB (`import sql.mysql`), ported from
[go-sql-driver/mysql](https://github.com/go-sql-driver/mysql) v1.9.3. It lives in
testcontainers-ae for now, where `wait.for_sql` uses it and the
integration tests drive it, and imports nothing of testcontainers so it
can move out into a package of its own (DESIGN.md section 14).

## Using it

```aether
import sql
import sql.postgres as pgsql

main() {
    pgsql.register()      // registers "postgres", "pgx" and "pgx/v5"; once, before open
    db, err = sql.open("postgres", "postgres://app:secret@localhost:5432/app?sslmode=disable")
    if err != "" { println(err); return }
    defer sql.close(db)

    _, err = sql.exec(db, "CREATE TABLE IF NOT EXISTS people (id int PRIMARY KEY, name text, born date, photo bytea)", [])
    res, err = sql.exec(db, "INSERT INTO people VALUES ($1, $2, $3, $4)",
                        [sql.int64(1), sql.text("Ada"), sql.text("1815-12-10"), sql.null_value()])
    println("inserted ${sql.rows_affected(res)}")

    rows, err = sql.query(db, "SELECT id, name, photo FROM people WHERE id >= $1", [sql.int64(1)])
    while sql.next(rows) {
        id, _ = sql.int_at(rows, 0)
        name, _ = sql.string_at(rows, 1)
        has_photo = !sql.is_null_at(rows, 2)
        println("${id} ${name} ${has_photo}")
    }
    sql.close_rows(rows)

    row, err = sql.query_row(db, "SELECT count(*) FROM people", [])   // sql.ERR_NO_ROWS if none
    n, _ = sql.int_at(row, 0)

    tx, err = sql.begin(db)
    _, err = sql.tx_exec(tx, "DELETE FROM people WHERE id = $1", [sql.int64(1)])
    err = sql.rollback(tx)                                             // or sql.commit(tx)

    st, err = sql.prepare(db, "SELECT name FROM people WHERE id = $1")
    r, err = sql.stmt_query_row(st, [sql.int64(1)])
    sql.stmt_close(st)
}
```

Errors are strings (`""` is success). A PostgreSQL error reads as pgx's
does, with the detail and position after it when the server sent them:
`ERROR: duplicate key value violates unique constraint "people_pkey"
(SQLSTATE 23505) detail=Key (id)=(1) already exists.`;
`sql.sqlstate(err)` gives `"23505"`.

Values in: `sql.text(s)`, `sql.int64(n)`, `sql.float64(f)`,
`sql.boolean(b)`, `sql.blob(bytes)`, `sql.null_value()`. Values out:
`string_at`, `int_at`, `float_at`, `bool_at`, `bytes_at` (each `(value,
err)`; NULL is an error except for `bytes_at`, as in Go), `is_null_at`,
`column_names`, `column_types` (pgx's names: `INT4`, `TEXT`, `BYTEA`, ...).
A timestamp, a numeric, a UUID, JSON: read them with `string_at`, in
PostgreSQL's text form.

### Connection strings (pgx's `ParseConfig`)

- URL: `postgres://user:password@host:port/database?key=value&...`
  (`postgresql://` too), percent-encoded; several hosts as
  `host1:5432,host2:5433`; a Unix socket directory as `?host=/tmp`.
- Keyword/value: `host=localhost port=5432 user=app password='a b' dbname=app sslmode=disable`.
- The `PG*` environment variables fill what the string does not say;
  libpq's defaults fill the rest (port 5432, the OS user, a Unix socket
  directory if one exists, else localhost).
- `sslmode`, `sslrootcert`, `sslsni`, `connect_timeout` (seconds, the whole
  connection attempt), `target_session_attrs`, `channel_binding`,
  `min_protocol_version`/`max_protocol_version`; any other key is sent to
  the server as a run-time parameter (`application_name`, `search_path`,
  `timezone`, ...).

## PostgreSQL: what is supported, what is not

| | |
|---|---|
| Authentication | trust, cleartext password, MD5, SCRAM-SHA-256. No GSS/SSPI/Kerberos, OAUTHBEARER, channel binding (`SCRAM-SHA-256-PLUS`). The SCRAM password is not SASLprep'd (identical for ASCII; PostgreSQL accepts either). |
| TLS | TLS 1.3 only, by SSLRequest on the same socket, through `std.cryptography.tls13_client`. The server is always verified, chain and host name (IP SANs too), against `sslrootcert` or the system store. `sslmode=verify-full` works as in pgx; `verify-ca` checks the host name too; `require` without `sslrootcert` is refused (it asks for no verification); `prefer` (the default) and `allow` try a verified TLS connection and fall back to plain text when it fails, where pgx would make an unverified TLS connection. No client certificates (`sslcert`/`sslkey`), no `sslnegotiation=direct`. |
| Protocol | 3.0; simple query protocol for statements without arguments (several statements in one string), extended protocol with arguments; text format in and out. |
| Types | Text in and out. `bytea` is hex-encoded going in and decoded (hex or escape format) coming out; everything else is PostgreSQL's text, converted by the accessors. No binary format, no array/composite/range decoding. |
| Connections | One per `*sql.DB`, made on first use, made again after a broken one; prepared statements are prepared again on the new connection. No pool: a DB is for one thread, and while a transaction is open the DB's own calls refuse (use the `Tx`). |
| Results | Read whole before the call returns (no streaming); `next`/`close_rows` work over them as Go's do. |
| Not ported | `.pgpass`, service files, COPY, LISTEN/NOTIFY delivery, cancel requests, pipelines and batches, protocol 3.2, contexts (deadlines are `connect_timeout` and the socket's 30 s read timeout), `LastInsertId` (use `RETURNING`, as with pgx). |

The TLS limits come from `std.cryptography.tls13_client.connect_socket`,
the one entry point that runs TLS over a socket the caller already holds:
it takes a host name to verify and a CA file, and has no way to skip
verification, verify the chain only, or present a client certificate. Its
internal `connect_full` has the verification bits (and `connect_mtls` a
client certificate, ECDSA P-256 only) but neither is exported for an
adopted socket.

## MySQL and MariaDB (`sql.mysql`)

```aether
import sql
import sql.mysql as mysqldrv      // alias it: modules.mysql has the same last name

main() {
    mysqldrv.register()            // registers "mysql"; once, before open
    db, err = sql.open("mysql", "app:secret@tcp(localhost:3306)/app")
    if err != "" { println(err); return }
    defer sql.close(db)
    res, err = sql.exec(db, "INSERT INTO people (name, photo) VALUES (?, ?)", [sql.text("Ada"), sql.null_value()])
    id, _ = sql.last_insert_id(res)                  // from the OK packet
    row, err = sql.query_row(db, "SELECT name, born FROM people WHERE id = ?", [sql.int64(id)])
    name, _ = sql.string_at(row, 0)
    born, _ = sql.string_at(row, 1)                  // DATETIME as MySQL's text: "1815-12-10 00:00:00"
}
```

Placeholders are `?`. A statement with no arguments runs as `COM_QUERY`
(the text protocol); one with arguments is prepared, executed with the
binary protocol and closed, as `database/sql` does when Go's driver
answers `driver.ErrSkip` (with `interpolateParams=true` the arguments are
escaped into the SQL text instead, as Go does). `sql.prepare` keeps the
statement (`COM_STMT_PREPARE`, `COM_STMT_EXECUTE`, `COM_STMT_CLOSE`). An
error reads as Go's `MySQLError`: `Error 1146 (42S02): Table 'app.nope'
doesn't exist`; `sql.sqlstate(err)` gives `"42S02"` and
`mysqldrv.error_number(err)` gives `1146`.

Values come back as text, the way `database/sql` would convert Go's to a
string: integers in decimal (unsigned BIGINT above 2^63 too), FLOAT and
DOUBLE in strconv's shortest form (`0.1`, `3.14`, `1e-05`), DATE,
DATETIME, TIMESTAMP and TIME as MySQL writes them, DECIMAL, ENUM, SET,
JSON and strings as sent, BLOB and BINARY as their bytes, a TINYINT(1) as
`0`/`1` (`bool_at` reads it). `column_types` gives Go's
`DatabaseTypeName` (`INT`, `UNSIGNED BIGINT`, `VARCHAR`, `TEXT`, `BLOB`,
`DATETIME`, `DECIMAL`, ...).

### DSNs (go-sql-driver's `ParseDSN`)

`[user[:password]@][net[(addr)]]/dbname[?param1=value1&paramN=valueN]`:

- `app:secret@tcp(localhost:3306)/app`, `tcp([::1]:3306)`, `tcp(host)`
  (port 3306), `/app` (127.0.0.1:3306), `unix(/var/run/mysqld/mysqld.sock)/app`.
- The password runs to the last `@`, the address to the last `/`, so
  neither needs escaping; the database name is path-escaped, values
  query-escaped.
- Every v1.9.3 parameter parses: `tls`, `serverPubKey`,
  `allowCleartextPasswords`, `allowNativePasswords`, `allowOldPasswords`,
  `allowFallbackToPlaintext`, `charset` (`SET NAMES`), `collation`,
  `clientFoundRows`, `columnsWithAlias`, `interpolateParams`,
  `multiStatements`, `maxAllowedPacket` (0: ask the server),
  `connectionAttributes`, `rejectReadOnly`, `timeout`, `readTimeout`, and
  any other key is a system variable set after connecting (`SET
  time_zone = '+00:00'`, in the DSN's order). Parsed but without effect:
  `parseTime` and `loc` (values stay text), `compress`, `allowAllFiles`,
  `checkConnLiveness`, `writeTimeout`, `timeTruncate`.
- `timeout` bounds the connection attempt's reads (std.tcp has no dial
  timeout), `readTimeout` each read of a plain-text connection.

### Authentication

| Plugin | |
|---|---|
| `caching_sha2_password` (MySQL 8's default) | The SHA-256 scramble. Fast auth when the server has the password cached; full auth otherwise: in cleartext over TLS or a Unix socket, else encrypted with the server's RSA key (fetched from the server, or the one registered with `mysqldrv.register_server_pub_key(name, pem)` and named by `serverPubKey=name`), RSA-OAEP with SHA-1 as MySQL and Go use. |
| `sha256_password` | The same RSA path (cleartext over TLS). |
| `mysql_native_password` (MariaDB's default) | The SHA-1 scramble; `allowNativePasswords=false` refuses it. |
| `mysql_clear_password` | Only with `allowCleartextPasswords=true`. |
| `mysql_old_password` | Only with `allowOldPasswords=true` (pre-4.1, insecure). |
| auth switch requests | Followed once, as Go does (the old-style switch too). |
| `client_ed25519` (MariaDB) | Not ported: `std.cryptography.ed25519` signs from a 32-byte seed, and the plugin needs the scalar of SHA-512 of a password of any length. |

`std.cryptography.rsa` offers OAEP with SHA-256 only, so the OAEP-SHA-1
block is built in `sql/mysql/mysqlproto` (RFC 8017 7.1.1) over
`rsa.raw_encrypt`; the unit test decrypts it with a private key and
`openssl pkeyutl -pkeyopt rsa_oaep_md:sha1` decrypts it too.

### TLS: what each `tls=` does here

The handshake's SSL request, then TLS 1.3 over the same socket through
`std.cryptography.tls13_client.connect_socket`, which always verifies the
chain and the host name (MySQL 8 and MariaDB 10.6+ speak TLS 1.3):

| `tls=` | go-sql-driver | here |
|---|---|---|
| absent, `false` | plain text | plain text |
| `true` | verified against the system roots and the host | the same |
| a name registered with `mysqldrv.register_tls_config(name, ca_file, server_name)` | Go's `RegisterTLSConfig` (`RootCAs`, `ServerName`) | verified against `ca_file` (`""`: the system roots) and `server_name` (`""`: the DSN's host) |
| `skip-verify` | TLS without verification | refused at connect, before dialling: no unverified TLS |
| `preferred` | unverified TLS when the server offers it, plain text when not | verified TLS (system roots) when the server offers it, and an error saying so when the certificate does not verify; plain text when the server offers no TLS, as Go |

With `allowFallbackToPlaintext=true` and `tls=true` (or a registered
name) a server without TLS gets plain text, as in Go. No client
certificates.

### What is left out

LOAD DATA LOCAL INFILE (the server's request is answered with an empty
file and an error), compression, `parseTime` (no `time.Time` here),
`client_ed25519`, the connection pool and context cancellation (as in
`sql/postgres`), streaming rows (a result is read whole; a query keeps
its first result set with columns and drops the rest, as Go's
`Rows.Close` does), `CLIENT_DEPRECATE_EOF` (not requested, as v1.9.3 does
not), custom dial functions, the full collations table (the default
`utf8mb4_general_ci` and a few common ones).

## Adding a driver

`sql/module.ae`'s `struct Driver` documents the contract of each function;
`sql/postgres/module.ae` is the model (`sql/mysql/module.ae` the second). A driver module exports a
`register()` that builds its vtable with `sql.new_driver(name)` and calls
`sql.register(name, d)` for each name Go code knows it by. It must not
import testcontainers (`tests/run.sh` checks).

## Tests

- `tests/test_sql_unit.ae`: `sql` with a mock driver, no database.
- `tests/test_sql_postgres_unit.ae`: the PostgreSQL driver's pure parts
  (message bytes, decoding, SCRAM against RFC 7677, MD5, `ParseConfig`
  cases from pgx's tests, parameter encoding, bytea).
- `tests/test_sql_postgres.ae`: against PostgreSQL 16 in a container
  (SCRAM, MD5, TLS with the test CA in `tests/fixtures/pgtls`, errors,
  transactions, prepared statements, `wait.for_sql`).
- `tests/test_sql_mysql_unit.ae`: the MySQL driver's pure parts (packet
  framing over 0xffffff bytes, length-encoded values, `ParseDSN` cases
  from `dsn_test.go`, the scrambles against `auth_test.go`'s vectors, the
  authentication exchanges over a mock connection with Go's captured
  bytes, ERR/OK/EOF and handshake decoding, binary rows, RSA-OAEP).
- `tests/test_sql_mysql.ae`: against MySQL 8.0.36 (caching_sha2_password
  full and fast, `serverPubKey`, TLS 1.3 with the test CA, a 17 MB blob,
  long data, errors, transactions, `wait.for_sql`) and MariaDB 12.3.2
  (mysql_native_password).

## License

MIT, except `sql/mysql/`. `sql/postgres/` is ported from jackc/pgx (MIT,
copyright (c) 2013-2021 Jack Christensen): `LICENSE` here carries its
license. `sql/mysql/` is ported from go-sql-driver/mysql (Copyright 2012
The Go-MySQL-Driver Authors) and stays under the Mozilla Public License
2.0: `mysql/LICENSE` has its text, `mysql/AUTHORS` the authors, and each
ported file the MPL notice. `NOTICE` says what came from which file.
