#!/bin/sh
# Checks of spec 001 of multi-tour-operations-cost-db (HU-OPS-001). One function per check, named as in plan.md section 4:
#   I·schema_builds_from_empty_and_nothing_lives_in_public            AC-DB-01.1
#   I·a_second_run_applies_zero_changesets                            AC-DB-01.9
#   I·the_full_rollback_leaves_nothing_and_the_rebuild_is_identical   AC-DB-01.10
#   I·own_control_table_no_database_service_no_volume_no_extension    AC-DB-01.11
#   I·operations_cost_app_writes_only_its_schema                      AC-DB-01.12
#   I·a_departure_missing_any_mandatory_value_is_refused               AC-DB-01.2
#   I·an_end_before_the_start_is_refused_and_one_days_later_is_accepted AC-DB-01.3
#   I·only_the_four_states_of_the_pdr_are_accepted                     AC-DB-01.4
#   I·the_tenant_is_mandatory_and_indexed_with_state_and_start         AC-DB-01.5
#   I·the_application_user_cannot_delete_a_departure                   AC-DB-01.6
#   I·an_idempotency_key_is_unique_and_8_to_128_characters             AC-DB-01.7
#   I·an_outbox_row_needs_its_type_tenant_payload_and_instant          AC-DB-01.8
# Checks of spec 002 (HU-OPS-002, the vehicles):
#   I·a_vehicle_has_a_name_and_a_capacity_in_range                     AC-DB-02.1
#   I·a_vehicle_name_is_unique_in_a_tenant_ignoring_case_and_spaces    AC-DB-02.2
#   I·the_application_user_cannot_delete_a_vehicle                     AC-DB-02.3, -02.6
#   I·an_assignment_joins_a_vehicle_and_a_departure_of_one_tenant      AC-DB-02.4, -02.5
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
  docker rm -fv "$RUN_ID" >/dev/null 2>&1 || true
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
  psql_admin -c "SELECT coalesce(md5(string_agg(part, ',' ORDER BY part)), '') FROM (
      SELECT 'column:' || table_name || '.' || column_name || ':' || data_type || ':' || is_nullable AS part
        FROM information_schema.columns WHERE table_schema = '$SCHEMA'
      UNION ALL SELECT 'index:' || indexdef FROM pg_indexes WHERE schemaname = '$SCHEMA'
      UNION ALL SELECT 'constraint:' || conrelid::regclass::text || ':' || pg_get_constraintdef(oid) FROM pg_constraint
        WHERE connamespace = '$SCHEMA'::regnamespace
      UNION ALL SELECT 'grant:' || grantee || ':' || table_name || ':' || privilege_type FROM information_schema.role_table_grants
        WHERE table_schema = '$SCHEMA' AND grantee LIKE 'operations_cost%'
    ) x"
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
  ! grep -Eq "^\s*(image:\s*[\"']?[a-z/]*postgres|volumes:)" deploy/compose.yml || { echo "deploy/compose.yml defines a database service or a volume"; return 1; }
  # J.4: the extensions belong to the infrastructure; none is created by the migrations, in the source or in the engine
  ! grep -rqi "CREATE EXTENSION" 01_ddl 02_dml 03_dcl changelog || { echo "a migration creates an extension"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_extension WHERE extname <> 'plpgsql'")" = 0 ] || { echo "an extension exists after the migrations"; return 1; }
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
  mine=$(writable_schemas)
  [ "$mine" = "$SCHEMA" ] || { echo "operations_cost_app must write in $SCHEMA and nowhere else, and can write in: '$mine'"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', 'public', 'CREATE')")" = "f" ] || { echo "operations_cost_app can create in public"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', '$SCHEMA', 'CREATE')")" = "f" ] || { echo "operations_cost_app can create objects in $SCHEMA"; return 1; }
  [ "$(psql_admin -c "SELECT has_schema_privilege('operations_cost_app', '$SCHEMA', 'USAGE')")" = "t" ] || { echo "operations_cost_app cannot use $SCHEMA"; return 1; }
}

# ---- the probes of the departure (spec 001, task DB-02): what the engine refuses
T1=00000000-0000-4000-8000-0000000000a1
T2=00000000-0000-4000-8000-0000000000a2
SVC=00000000-0000-4000-8000-0000000000c1
ACTOR=00000000-0000-4000-8000-0000000000d1

psql_app() { docker exec -e PGPASSWORD="$APP_PASSWORD" "$RUN_ID" psql -h 127.0.0.1 -U operations_cost_app -d "$DB" -v ON_ERROR_STOP=1 -tA "$@"; }

# a statement the database must refuse, for the reason named by a fragment of its message
refused() { # fragment, statement
  out=$(psql_admin -c "$2" 2>&1) && { echo "the database accepted: $2"; return 1; }
  printf '%s' "$out" | grep -q "$1" || { echo "refused, but not for the expected reason ($1): $out"; return 1; }
}
# one insert of a departure; each argument is a column=value override, the rest is valid
departure() { # [column=value ...]
  id="gen_random_uuid()"; tenant="'$T1'"; code="'SAL-001'"; service="'$SVC'"; starts="'2026-12-01 08:00:00+00'"
  ends="'2026-12-01 18:00:00+00'"; zone="'America/Bogota'"; status="'SCHEDULED'"; by="'$ACTOR'"; at="now()"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      id) id=$v ;; tenant) tenant=$v ;; code) code=$v ;; service) service=$v ;; starts) starts=$v ;;
      ends) ends=$v ;; zone) zone=$v ;; status) status=$v ;; by) by=$v ;; at) at=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida (salida_id, tenant_id, code, service_id, starts_at, estimated_end_at, time_zone, status, scheduled_by, scheduled_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)" \
    "$id" "$tenant" "$code" "$service" "$starts" "$ends" "$zone" "$status" "$by" "$at"
}
# the key table references the departures, so both are truncated together
# (the vehicle tables are included when they exist, so the checks of spec 001 also run on a schema without them)
clean_departures() {
  tables=$(psql_admin -c "SELECT string_agg(format('%I.%I', schemaname, tablename), ',') FROM pg_tables
    WHERE schemaname = '$SCHEMA' AND tablename IN ('idempotency_key', 'salida', 'salida_vehicle', 'vehicle')")
  psql_admin -c "TRUNCATE $tables" >/dev/null || { echo "could not clean the departures"; return 1; }
}

a_departure_missing_any_mandatory_value_is_refused() {
  clean_departures || return 1
  psql_admin -c "$(departure)" >/dev/null || { echo "a complete departure was refused"; return 1; }
  for kv in id=NULL tenant=NULL code=NULL service=NULL starts=NULL ends=NULL zone=NULL status=NULL by=NULL at=NULL; do
    refused "null value in column" "$(departure "$kv")" || { echo "  (override $kv)"; return 1; }
  done
  refused chk_salida_time_zone "$(departure "zone=''")" || return 1
  refused chk_salida_time_zone "$(departure "zone='$(printf 'z%.0s' $(seq 1 65))'")" || return 1
  psql_admin -c "$(departure "code='SAL-002'" "zone='$(printf 'z%.0s' $(seq 1 64))'")" >/dev/null || { echo "a zone of 64 characters was refused"; return 1; }
}
an_end_before_the_start_is_refused_and_one_days_later_is_accepted() {
  clean_departures || return 1
  refused chk_salida_estimated_end_at "$(departure "ends='2026-12-01 07:59:59+00'")" || return 1
  psql_admin -c "$(departure "code='SAL-002'" "ends='2026-12-01 08:00:00+00'")" >/dev/null || { echo "an end equal to the start was refused"; return 1; }
  psql_admin -c "$(departure "code='SAL-003'" "ends='2026-12-04 18:00:00+00'")" >/dev/null || { echo "an end three days later was refused"; return 1; }
}
only_the_four_states_of_the_pdr_are_accepted() {
  clean_departures || return 1
  n=10
  for status in SCHEDULED IN_EXECUTION FINISHED CANCELLED; do
    n=$((n + 1))
    psql_admin -c "$(departure "code='SAL-0$n'" "status='$status'")" >/dev/null || { echo "the state $status was refused"; return 1; }
  done
  refused chk_salida_status "$(departure "code='SAL-099'" "status='PENDING_REGULARIZATION'")" || return 1
  refused chk_salida_status "$(departure "code='SAL-098'" "status='Programada'")"
}
the_tenant_is_mandatory_and_indexed_with_state_and_start() {
  clean_departures || return 1
  psql_admin -c "$(departure)" >/dev/null || return 1
  refused uq_salida_tenant_id_code "$(departure)" || return 1
  psql_admin -c "$(departure "tenant='$T2'")" >/dev/null || { echo "the same code in another tenant was refused"; return 1; }
  refused chk_salida_code "$(departure "code='SAL-1'")" || return 1
  refused chk_salida_code "$(departure "code='sal-001'")" || return 1
  refused chk_salida_code "$(departure "code='SAL-12'")" || return 1
  refused chk_salida_code "$(departure "code='SAL-1234567'")" || return 1
  psql_admin -c "$(departure "code='SAL-123456'")" >/dev/null || { echo "a code of six digits was refused"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM pg_constraint WHERE connamespace = 'operations_cost'::regnamespace AND contype = 'f'
    AND (confrelid::regclass::text NOT LIKE 'operations_cost.%' OR conrelid = 'operations_cost.salida'::regclass)")" = 0 ] \
    || { echo "a foreign key leaves the domain or starts in the departure: the tenant and the tour belong to other domains (Annex J.3.4)"; return 1; }
  def=$(psql_admin -c "SELECT indexdef FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_salida_tenant_id_status_starts_at'")
  case "$def" in
    *"(tenant_id, status, starts_at)"*) ;;
    *) echo "the index must be on (tenant_id, status, starts_at): '$def'"; return 1 ;;
  esac
}
the_application_user_cannot_delete_a_departure() {
  clean_departures || return 1
  psql_admin -c "$(departure)" >/dev/null || return 1
  psql_app -c "UPDATE operations_cost.salida SET status = 'CANCELLED'" >/dev/null || { echo "the application user cannot update a departure"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.salida" 2>&1) && { echo "the application user deleted a departure"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM operations_cost.salida")" = 1 ] || { echo "the departure is gone"; return 1; }
}

# ---- the probes of the outbox and of the idempotency key (spec 001, task DB-03)
clean_outbox() { psql_admin -c "TRUNCATE operations_cost.idempotency_key, operations_cost.outbox_event" >/dev/null || { echo "could not clean the outbox"; return 1; }; }
event() { # [column=value ...]: an event of the outbox, valid unless overridden
  tenant="'$T1'"; type="'SalidaScheduled'"; aggregate="'$SVC'"; payload="'{\"code\":\"SAL-001\"}'"; correlation="'trace-001'"; occurred="now()"; status="'PENDING'"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      tenant) tenant=$v ;; type) type=$v ;; aggregate) aggregate=$v ;; payload) payload=$v ;; correlation) correlation=$v ;;
      occurred) occurred=$v ;; status) status=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.outbox_event (tenant_id, event_type, aggregate_id, payload, correlation_id, occurred_at, status) VALUES (%s, %s, %s, %s, %s, %s, %s)" \
    "$tenant" "$type" "$aggregate" "$payload" "$correlation" "$occurred" "$status"
}
key() { # scope, key, departure id
  printf "INSERT INTO operations_cost.idempotency_key (scope, idempotency_key, salida_id) VALUES ('%s', '%s', '%s')" "$1" "$2" "$3"
}

an_outbox_row_needs_its_type_tenant_payload_and_instant() {
  clean_outbox || return 1
  psql_admin -c "$(event)" >/dev/null || { echo "a complete event was refused"; return 1; }
  for kv in tenant=NULL type=NULL aggregate=NULL payload=NULL correlation=NULL occurred=NULL; do
    refused "null value in column" "$(event "$kv")" || { echo "  (override $kv)"; return 1; }
  done
  refused chk_outbox_event_status "$(event "status='DONE'")" || return 1
  refused chk_outbox_event_event_type "$(event "type=''")" || return 1
  refused chk_outbox_event_event_type "$(event "type='$(printf 't%.0s' $(seq 1 101))'")" || return 1
  refused chk_outbox_event_correlation_id "$(event "correlation=''")" || return 1
  # what a fresh row holds: it stays PENDING and unpublished until the relay publishes it (ADR-004 D4)
  [ "$(psql_admin -c "SELECT status || ':' || attempts || ':' || (published_at IS NULL) FROM operations_cost.outbox_event")" = "PENDING:0:true" ] || { echo "a new event must be pending, with no attempt and unpublished"; return 1; }
  refused chk_outbox_event_attempts "UPDATE operations_cost.outbox_event SET attempts = -1" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_outbox_event_status_next_attempt_at'")" = 1 ] || { echo "the index of the relay is missing"; return 1; }
  # the service writes the event in the same transaction as the departure, so the application user must insert it too
  psql_app -c "$(event "correlation='trace-002'")" >/dev/null || { echo "the application user cannot insert an event"; return 1; }
  psql_app -c "UPDATE operations_cost.outbox_event SET status = 'PUBLISHED', published_at = now()" >/dev/null || { echo "the application user cannot update an event"; return 1; }
}
an_idempotency_key_is_unique_and_8_to_128_characters() {
  clean_departures || return 1
  clean_outbox || return 1
  psql_admin -c "$(departure)" >/dev/null || return 1
  id=$(psql_admin -c "SELECT salida_id FROM operations_cost.salida LIMIT 1")
  psql_admin -c "$(key creation:$T1 abcdefgh "$id")" >/dev/null || { echo "a valid key was refused"; return 1; }
  refused pk_idempotency_key "$(key creation:$T1 abcdefgh "$id")" || return 1
  psql_admin -c "$(key creation:$T2 abcdefgh "$id")" >/dev/null || { echo "the same key in another scope was refused"; return 1; }
  refused chk_idempotency_key_length "$(key creation:$T1 abcdefg "$id")" || return 1
  refused chk_idempotency_key_length "$(key creation:$T1 "$(printf 'k%.0s' $(seq 1 129))" "$id")" || return 1
  psql_admin -c "$(key creation:$T1 "$(printf 'k%.0s' $(seq 1 128))" "$id")" >/dev/null || { echo "a key of 128 characters was refused"; return 1; }
  # the key points to the departure it created and that departure cannot disappear from under it
  refused fk_idempotency_key_salida "$(key creation:$T1 hgfedcba 00000000-0000-4000-8000-0000000000ff)" || return 1
  refused fk_idempotency_key_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$id'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_idempotency_key_salida_id'")" = 1 ] || { echo "the index of the foreign key is missing"; return 1; }
  psql_app -c "$(key creation:$T1 appkey001 "$id")" >/dev/null || { echo "the application user cannot write a key"; return 1; }
}

# ---- the probes of the vehicles (spec 002, task DB2-01)
V1=00000000-0000-4000-8000-0000000000e1
V2=00000000-0000-4000-8000-0000000000e2
vehicle() { # [column=value ...]: a vehicle, valid unless overridden
  id="'$V1'"; tenant="'$T1'"; name="'Van 1'"; capacity="12"; by="'$ACTOR'"; at="now()"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      id) id=$v ;; tenant) tenant=$v ;; name) name=$v ;; capacity) capacity=$v ;; by) by=$v ;; at) at=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.vehicle (vehicle_id, tenant_id, name, capacity, created_by, created_at) VALUES (%s, %s, %s, %s, %s, %s)" \
    "$id" "$tenant" "$name" "$capacity" "$by" "$at"
}
assignment() { # salida id, vehicle id, tenant
  printf "INSERT INTO operations_cost.salida_vehicle (tenant_id, salida_id, vehicle_id, assigned_by, assigned_at) VALUES ('%s', '%s', '%s', '%s', now())" "${3:-$T1}" "$1" "$2"  "$ACTOR"
}

a_vehicle_has_a_name_and_a_capacity_in_range() {
  clean_departures || return 1
  psql_admin -c "$(vehicle)" >/dev/null || { echo "a complete vehicle was refused"; return 1; }
  for kv in id=NULL tenant=NULL name=NULL capacity=NULL by=NULL at=NULL; do
    refused "null value in column" "$(vehicle "$kv")" || { echo "  (override $kv)"; return 1; }
  done
  refused chk_vehicle_name "$(vehicle "id='$V2'" "name=''")" || return 1
  refused chk_vehicle_name "$(vehicle "id='$V2'" "name='   '")" || return 1
  refused chk_vehicle_name "$(vehicle "id='$V2'" "name='$(printf 'n%.0s' $(seq 1 61))'")" || return 1
  refused chk_vehicle_capacity "$(vehicle "id='$V2'" "name='Van 2'" "capacity=0")" || return 1
  refused chk_vehicle_capacity "$(vehicle "id='$V2'" "name='Van 2'" "capacity=101")" || return 1
  psql_admin -c "$(vehicle "id='$V2'" "name='Van 2'" "capacity=1")" >/dev/null || { echo "a capacity of 1 was refused"; return 1; }
  psql_admin -c "$(vehicle "id=gen_random_uuid()" "name='Bus'" "capacity=100")" >/dev/null || { echo "a capacity of 100 was refused"; return 1; }
  psql_admin -c "$(vehicle "id=gen_random_uuid()" "name='$(printf 'n%.0s' $(seq 1 60))'")" >/dev/null || { echo "a name of 60 characters was refused"; return 1; }
}
a_vehicle_name_is_unique_in_a_tenant_ignoring_case_and_spaces() {
  clean_departures || return 1
  psql_admin -c "$(vehicle)" >/dev/null || return 1
  refused uq_vehicle_tenant_id_name "$(vehicle "id='$V2'" "name='van 1'")" || return 1
  refused uq_vehicle_tenant_id_name "$(vehicle "id='$V2'" "name='  VAN 1  '")" || return 1
  psql_admin -c "$(vehicle "id='$V2'" "tenant='$T2'")" >/dev/null || { echo "the same name in another tenant was refused"; return 1; }
}
the_application_user_cannot_delete_a_vehicle() {
  clean_departures || return 1
  psql_app -c "$(vehicle)" >/dev/null || { echo "the application user cannot insert a vehicle"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.vehicle")" = 1 ] || { echo "the application user cannot read a vehicle"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.vehicle" 2>&1) && { echo "the application user deleted a vehicle"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM operations_cost.vehicle")" = 1 ] || { echo "the vehicle is gone"; return 1; }
}
an_assignment_joins_a_vehicle_and_a_departure_of_one_tenant() {
  clean_departures || return 1
  psql_admin -c "$(departure "id='00000000-0000-4000-8000-0000000000f1'")" >/dev/null || return 1
  psql_admin -c "$(departure "id='00000000-0000-4000-8000-0000000000f2'" "tenant='$T2'")" >/dev/null || return 1
  psql_admin -c "$(vehicle)" >/dev/null || return 1
  S1=00000000-0000-4000-8000-0000000000f1; S2=00000000-0000-4000-8000-0000000000f2
  psql_admin -c "$(assignment $S1 $V1)" >/dev/null || { echo "a valid assignment was refused"; return 1; }
  refused pk_salida_vehicle "$(assignment $S1 $V1)" || return 1
  # the departure of another tenant, and a tenant that does not own the vehicle
  refused fk_salida_vehicle_salida "$(assignment $S2 $V1)" || return 1
  refused fk_salida_vehicle_vehicle "$(assignment $S2 $V1 $T2)" || return 1
  refused fk_salida_vehicle_salida "$(assignment 00000000-0000-4000-8000-0000000000ff $V1)" || return 1
  # neither side can disappear from under an assignment
  refused fk_salida_vehicle_vehicle "DELETE FROM operations_cost.vehicle WHERE vehicle_id = '$V1'" || return 1
  refused fk_salida_vehicle_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$S1'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_salida_vehicle_tenant_id_vehicle_id'")" = 1 ] || { echo "the index of the vehicle lookup is missing"; return 1; }
  # the service reads, adds and (part B) will remove assignments, never deletes a vehicle
  psql_admin -c "$(vehicle "id='$V2'" "name='Van 2'")" >/dev/null || return 1
  psql_app -c "$(assignment $S1 $V2)" >/dev/null || { echo "the application user cannot add an assignment"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.salida_vehicle")" = 2 ] || { echo "the application user cannot read the assignments"; return 1; }
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
check "I·a_departure_missing_any_mandatory_value_is_refused" a_departure_missing_any_mandatory_value_is_refused
check "I·an_end_before_the_start_is_refused_and_one_days_later_is_accepted" an_end_before_the_start_is_refused_and_one_days_later_is_accepted
check "I·only_the_four_states_of_the_pdr_are_accepted" only_the_four_states_of_the_pdr_are_accepted
check "I·the_tenant_is_mandatory_and_indexed_with_state_and_start" the_tenant_is_mandatory_and_indexed_with_state_and_start
check "I·the_application_user_cannot_delete_a_departure" the_application_user_cannot_delete_a_departure
check "I·an_idempotency_key_is_unique_and_8_to_128_characters" an_idempotency_key_is_unique_and_8_to_128_characters
check "I·an_outbox_row_needs_its_type_tenant_payload_and_instant" an_outbox_row_needs_its_type_tenant_payload_and_instant
check "I·a_vehicle_has_a_name_and_a_capacity_in_range" a_vehicle_has_a_name_and_a_capacity_in_range
check "I·a_vehicle_name_is_unique_in_a_tenant_ignoring_case_and_spaces" a_vehicle_name_is_unique_in_a_tenant_ignoring_case_and_spaces
check "I·the_application_user_cannot_delete_a_vehicle" the_application_user_cannot_delete_a_vehicle
check "I·an_assignment_joins_a_vehicle_and_a_departure_of_one_tenant" an_assignment_joins_a_vehicle_and_a_departure_of_one_tenant
check "I·the_full_rollback_leaves_nothing_and_the_rebuild_is_identical" the_full_rollback_leaves_nothing_and_the_rebuild_is_identical

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
