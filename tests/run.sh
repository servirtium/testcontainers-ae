#!/bin/sh
# Run every test: tests/test_*.ae, each a std.spec program, with `ae test`.
#
#   tests/run.sh                 all of them
#   tests/run.sh test_redis.ae   some of them (names under tests/)
#
# The engine is found as the library finds it (DESIGN.md section 8); this
# script only helps on a Mac with a Podman machine and no DOCKER_HOST, by
# pointing DOCKER_HOST at the machine's API socket, so the run says which
# engine it used. With no engine at all the engine-backed files skip.
#
# After the run it waits for the reapers of the run's sessions to finish and
# checks that nothing labelled org.testcontainers.lang=aether is left.
#
# Images: the module tests pull 30-40 GB of service images between them,
# more than a Podman machine's disk holds beside anything else. So by default
# each test file runs on its own and, once its containers are gone, the
# images that appeared while it ran are removed. Images that were there
# before the file started (the engine's other images) are never touched.
# TCAE_KEEP_IMAGES=1 keeps everything and runs the files in one `ae test`
# call, for repeated local runs.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT" || exit 1

if ! command -v ae >/dev/null 2>&1; then
    echo "ae is not on PATH" >&2
    exit 1
fi

if [ -z "${DOCKER_HOST:-}" ] && command -v podman >/dev/null 2>&1 && [ "$(uname -s)" = Darwin ]; then
    p=$(podman machine inspect --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null | head -1)
    if [ -n "$p" ] && [ -S "$p" ]; then
        DOCKER_HOST="unix://$p"
        export DOCKER_HOST
    fi
fi
echo "ae: $(command -v ae) ($(ae version 2>/dev/null | head -1))"

# The one-way rule (DESIGN.md section 14): sql/ is to be teased out into a
# package of its own, so nothing under it may import testcontainers or the
# modules; only tests may use both.
bad=$(grep -rnE --include='*.ae' '^[[:space:]]*import[[:space:]]+(testcontainers|modules)([.[:space:]]|$)' sql/ 2>/dev/null)
if [ -n "$bad" ]; then
    echo "sql/ must not import testcontainers or modules:" >&2
    echo "$bad" >&2
    exit 1
fi
echo "engine: ${DOCKER_HOST:-<discovered by the library>}"

if [ "$#" -gt 0 ]; then
    files=""
    for f in "$@"; do files="$files tests/$f"; done
else
    files=$(ls tests/test_*.ae)
fi

# What is left: the reapers clean up ryuk.reconnection.timeout (10s) after
# their test process ends. Give them that, then look.
leftover() {
    if command -v podman >/dev/null 2>&1; then
        podman ps -a --filter label=org.testcontainers.lang=aether --format '{{.ID}} {{.Names}} {{.Status}}' 2>/dev/null
    elif command -v docker >/dev/null 2>&1; then
        docker ps -a --filter label=org.testcontainers.lang=aether --format '{{.ID}} {{.Names}} {{.Status}}' 2>/dev/null
    fi
}
wait_reaped() {
    if [ -n "$(leftover)" ]; then
        n=0
        while [ -n "$(leftover)" ] && [ $n -lt 60 ]; do sleep 1; n=$((n + 1)); done
    fi
}

ENGINE_CLI=""
if command -v podman >/dev/null 2>&1; then ENGINE_CLI=podman
elif command -v docker >/dev/null 2>&1; then ENGINE_CLI=docker
fi
image_ids() { [ -n "$ENGINE_CLI" ] && $ENGINE_CLI images -q --no-trunc 2>/dev/null | sort -u; }

if [ "${TCAE_KEEP_IMAGES:-}" = 1 ] || [ -z "$ENGINE_CLI" ]; then
    # shellcheck disable=SC2086
    ae test $files
    rc=$?
    wait_reaped
else
    rc=0
    passed=0
    failed=0
    dropped=0
    for f in $files; do
        before=$(image_ids)
        if ae test "$f"; then passed=$((passed + 1)); else failed=$((failed + 1)); rc=1; fi
        wait_reaped
        after=$(image_ids)
        for id in $after; do
            case "$before" in *"$id"*) continue ;; esac
            if $ENGINE_CLI rmi "$id" >/dev/null 2>&1; then dropped=$((dropped + 1)); fi
        done
    done
    echo "$passed passed, $failed failed, $((passed + failed)) total (one file at a time); $dropped image(s) pulled by the run removed"
fi
left=$(leftover)
if [ -n "$left" ]; then
    echo "LEFT RUNNING after the reapers' timeout:"
    echo "$left"
    rc=1
else
    echo "nothing left running (label org.testcontainers.lang=aether)"
fi
exit $rc
