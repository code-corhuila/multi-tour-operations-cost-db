#!/bin/sh
# Checks of spec 001 of multi-tour-operations-cost-db (HU-OPS-001). One function per check, named as in plan.md section 4:
#   I·schema_builds_from_empty_and_nothing_lives_in_public            AC-DB-01.1
#   I·a_second_run_applies_zero_changesets                            AC-DB-01.9
#   I·the_full_rollback_leaves_nothing_and_the_rebuild_is_identical   AC-DB-01.10
#   I·own_control_table_no_database_service_no_volume_no_extension    AC-DB-01.11
#   I·operations_cost_app_writes_only_its_schema                      AC-DB-01.12
# Later tasks add the checks of the departure, the outbox and the idempotency key to this same file.
#
# It starts its own throwaway PostgreSQL (the image of multi-tour-infra-postgres) and builds the runner image of
# deploy/Dockerfile on a private network, with passwords generated now, so it touches nothing else and writes no
# secret. Docker is the only requirement; the CI and a developer run this same file (Annex A, db-ci; Annex J, J.6, J.10).
set -u
cd "$(dirname "$0")/.." || exit 1

# Git Bash on Windows rewrites container paths such as /workspace; no effect elsewhere
export MSYS_NO_PATHCONV=1

POSTGRES_IMAGE="postgres:18.6-alpine"
RUN_ID="operations-cost-dbci-$$"
LIQUIBASE_IMAGE="$RUN_ID-liquibase"
DB="multitour_test"
SCHEMA="operations_cost"
ADMIN_PASSWORD="admin-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
APP_PASSWORD="app-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
fail=0

cleanup() {
  docker rm -f "$RUN_ID" >/dev/null 2>&1 || true
  docker network rm "$RUN_ID" >/dev/null 2>&1 || true
  docker rmi "$LIQUIBASE_IMAGE" >/dev/null 2>&1 || true
}
trap cleanup EXIT
trap 'exit 1' INT TERM

psql_admin() { docker exec -e PGPASSWORD="$ADMIN_PASSWORD" "$RUN_ID" psql -h 127.0.0.1 -U postgres -d "$DB" -v ON_ERROR_STOP=1 -tA "$@"; }

# The runner of deploy/compose.yml: the migrations travel inside its image, and this domain has its own control table (J.6)
lb() {
  docker run --rm --network "$RUN_ID" \
    -e LIQUIBASE_COMMAND_URL="jdbc:postgresql://$RUN_ID:5432/$DB" \
    -e LIQUIBASE_COMMAND_USERNAME=postgres -e LIQUIBASE_COMMAND_PASSWORD="$ADMIN_PASSWORD" \
    "$LIQUIBASE_IMAGE" --search-path=/workspace --changelog-file=changelog/changelog-master.yaml \
    --database-changelog-table-name=databasechangelog_operations_cost \
    --database-changelog-lock-table-name=databasechangeloglock_operations_cost "$@"
}

check() { # name, then the command that must succeed
  name=$1; shift
  if reason=$("$@" 2>&1); then
    echo "PASS  $name"
  else
    echo "FAIL  $name"
    printf '%s\n' "$reason" | tail -n 8 | sed 's/^/        /'
    fail=1
  fi
}

# A fingerprint of what the schema holds, so a rebuild that differs in anything shows as a difference
schema_fingerprint() {
  psql_admin -c "SELECT coalesce(md5(string_agg(table_name || '.' || column_name || ':' || data_type || ':' || is_nullable, ',' ORDER BY table_name, column_name)), '')
    FROM information_schema.columns WHERE table_schema = '$SCHEMA'"
}
changelog_state() {
  psql_admin -c "SELECT count(*) || ':' || coalesce(md5(string_agg(id || md5sum, ',' ORDER BY orderexecuted)), '') FROM databasechangelog_operations_cost"
}

# ---- AC-DB-01.1
schema_builds_from_empty_and_nothing_lives_in_public() {
  lb update >/dev/null 2>&1 || { lb update 2>&1 | tail -n 8; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.schemata WHERE schema_name = '$SCHEMA'")" = 1 ] || { echo "the schema $SCHEMA does not exist"; return 1; }
  # the two control tables of the runner live in public (J.6); nothing else of this domain may
  left=$(psql_admin -c "SELECT string_agg(c.relname, ',' ORDER BY c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v', 'm', 'S', 'f', 'p') AND c.relname NOT IN ('databasechangelog_operations_cost', 'databasechangeloglock_operations_cost')")
  [ -z "$left" ] || { echo "objects in public: $left"; return 1; }
}

# ---- AC-DB-01.9
a_second_run_applies_zero_changesets() {
  before=$(changelog_state)
  out=$(lb update 2>&1) || { printf '%s\n' "$out" | tail -n 8; return 1; }
  [ "$before" = "$(changelog_state)" ] || { echo "the second run changed the control table"; return 1; }
  case $before in 0:*) echo "no changeset was ever recorded"; return 1 ;; esac
}

# ---- AC-DB-01.10
the_full_rollback_leaves_nothing_and_the_rebuild_is_identical() {
  state=$(changelog_state); shape=$(schema_fingerprint)
  lb rollback-count 999 >/dev/null 2>&1 || { echo "rollback-count 999 failed"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.schemata WHERE schema_name = '$SCHEMA'")" = 0 ] || { echo "the schema $SCHEMA is still there"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_roles WHERE rolname IN ('operations_cost_reader', 'operations_cost_writer')")" = 0 ] || { echo "a role of the domain is still there"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid = m.member WHERE r.rolname = 'operations_cost_app'")" = 0 ] || { echo "operations_cost_app is still a member of a role"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_default_acl")" = 0 ] || { echo "a default privilege is left behind"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM databasechangelog_operations_cost")" = 0 ] || { echo "the control table still lists changesets"; return 1; }
  lb update >/dev/null 2>&1 || { echo "the rebuild failed"; return 1; }
  [ "$state" = "$(changelog_state)" ] || { echo "the rebuild recorded other changesets"; return 1; }
  [ "$shape" = "$(schema_fingerprint)" ] || { echo "the rebuilt schema is not the same"; return 1; }
}

# ---- AC-DB-01.11
own_control_table_no_database_service_no_volume_no_extension() {
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('databasechangelog_operations_cost', 'databasechangeloglock_operations_cost')")" = 2 ] || { echo "the control tables with the domain suffix are missing"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('databasechangelog', 'databasechangeloglock')")" = 0 ] || { echo "a default-named control table exists, two domains would share it"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_authid WHERE rolname IN ('operations_cost_reader', 'operations_cost_writer') AND NOT rolcanlogin AND rolpassword IS NULL")" = 2 ] || { echo "the roles must be NOLOGIN and have no password"; return 1; }
  [ "$(psql_admin -c "SELECT pg_has_role('operations_cost_app', 'operations_cost_writer', 'MEMBER')")" = t ] || { echo "operations_cost_app is not a member of operations_cost_writer"; return 1; }
  [ -f deploy/compose.yml ] || { echo "deploy/compose.yml is missing"; return 1; }
  # J.7: the only service is the runner; no database service, no volume
  grep -q "operations-cost-db-migrate" deploy/compose.yml || { echo "the runner operations-cost-db-migrate is not declared"; return 1; }
  ! grep -Eq "^\s*(image:\s*postgres|volumes:)" deploy/compose.yml || { echo "deploy/compose.yml defines a database service or a volume"; return 1; }
  # J.4: the extensions belong to the infrastructure
  ! grep -rqi "CREATE EXTENSION" 01_ddl 02_dml 03_dcl changelog || { echo "a migration creates an extension"; return 1; }
}

# ---- AC-DB-01.12: the positive control first, so the check cannot pass only because the other schema is out of reach
writable_schemas() {
  psql_admin -c "SELECT string_agg(DISTINCT table_schema, ',' ORDER BY table_schema) FROM information_schema.tables
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
      AND has_table_privilege('operations_cost_app', format('%I.%I', table_schema, table_name), 'INSERT,UPDATE,DELETE')"
}
operations_cost_app_writes_only_its_schema() {
  psql_admin -c "GRANT INSERT ON other_domain.probe TO operations_cost_app" >/dev/null || return 1
  seen=$(writable_schemas)
  psql_admin -c "REVOKE INSERT ON other_domain.probe FROM operations_cost_app" >/dev/null || return 1
  case "$seen" in *other_domain*) ;; *) echo "the privilege query did not see a granted write: '$seen'"; return 1 ;; esac
  [ "$(writable_schemas)" = "" ] || [ "$(writable_schemas)" = "$SCHEMA" ] || { echo "operations_cost_app can write in: $(writable_schemas)"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', 'public', 'CREATE')")" = "f" ] || { echo "operations_cost_app can create in public"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', '$SCHEMA', 'CREATE')")" = "f" ] || { echo "operations_cost_app can create objects in $SCHEMA"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', '$SCHEMA', 'USAGE')")" = "t" ] || { echo "operations_cost_app cannot use $SCHEMA"; return 1; }
}

# ---- the instance, as multi-tour-infra-postgres leaves it: the database, the user of the domain and another domain's schema
docker network create "$RUN_ID" >/dev/null || exit 1
docker run -d --name "$RUN_ID" --network "$RUN_ID" -e POSTGRES_PASSWORD="$ADMIN_PASSWORD" -e POSTGRES_DB="$DB" "$POSTGRES_IMAGE" >/dev/null || exit 1
tries=0
until psql_admin -c "SELECT 1" >/dev/null 2>&1; do
  tries=$((tries + 1)); [ "$tries" -gt 60 ] && { echo "PostgreSQL did not start"; exit 1; }
  sleep 1
done
psql_admin -c "CREATE ROLE operations_cost_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '$APP_PASSWORD'" \
           -c "ALTER ROLE operations_cost_app SET search_path = $SCHEMA" \
           -c "CREATE SCHEMA other_domain" -c "CREATE TABLE other_domain.probe (id integer)" >/dev/null || exit 1

if ! docker build -q -t "$LIQUIBASE_IMAGE" -f deploy/Dockerfile . >/dev/null 2>&1; then
  echo "FAIL  the runner image of deploy/Dockerfile does not build"
  fail=1
fi

check "I·schema_builds_from_empty_and_nothing_lives_in_public" schema_builds_from_empty_and_nothing_lives_in_public
check "I·a_second_run_applies_zero_changesets" a_second_run_applies_zero_changesets
check "I·own_control_table_no_database_service_no_volume_no_extension" own_control_table_no_database_service_no_volume_no_extension
check "I·operations_cost_app_writes_only_its_schema" operations_cost_app_writes_only_its_schema
check "I·the_full_rollback_leaves_nothing_and_the_rebuild_is_identical" the_full_rollback_leaves_nothing_and_the_rebuild_is_identical

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
