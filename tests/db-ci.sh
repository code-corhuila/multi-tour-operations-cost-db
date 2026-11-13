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
#   I·a_vehicle_key_is_unique_8_to_128_characters_and_points_to_its_vehicle  AC-DB-02.8
# Check of api spec 008 (HU-OPS-002 part B, the change of the vehicles):
#   I·the_application_user_deletes_an_assignment_and_never_a_vehicle         api 008 (D-07)
# Checks of spec 003 (HU-OPS-003, the real start and end):
#   I·the_execution_columns_exist_and_an_old_departure_is_not_interrupted  AC-DB-03.1
#   I·a_start_goes_with_the_execution_and_who_recorded_it              AC-DB-03.2
#   I·an_end_goes_with_a_finished_departure_after_its_start            AC-DB-03.3
#   I·an_interruption_finishes_the_departure_with_its_cause            AC-DB-03.4
#   I·the_application_user_records_the_execution                       AC-DB-03.6
# Checks of spec 005 (HU-OPS-004, the delivered and the undelivered services):
#   I·the_service_table_exists_with_one_row_per_reservation_of_a_departure   AC-DB-05.1
#   I·a_result_and_its_travelers_served_agree                                AC-DB-05.2
#   I·an_undelivered_service_has_its_cause_and_a_no_show_is_undelivered      AC-DB-05.3
#   I·a_service_belongs_to_a_departure_of_its_tenant                         AC-DB-05.4
#   I·the_application_user_records_but_never_deletes_a_service               AC-DB-05.6
# Checks of spec 006 (HU-OPS-007, the operational costs):
#   I·the_cost_table_keeps_many_lines_per_departure                          AC-DB-06.1
#   I·a_cost_needs_a_concept_and_an_amount_above_zero                        AC-DB-06.2
#   I·a_calculated_cost_is_the_unit_cost_times_the_travelers_and_a_manual_one_has_neither  AC-DB-06.3
#   I·a_cost_without_a_catalogued_cost_is_manual_and_justified               AC-DB-06.4
#   I·a_cost_belongs_to_a_departure_of_its_tenant                            AC-DB-06.5
#   I·a_cost_key_is_unique_in_a_tenant_and_8_to_128_characters               AC-DB-06.6
#   I·the_application_user_records_but_never_changes_a_cost                  AC-DB-06.8
# Checks of spec 007 (HU-OPS-005, the extraordinary cancellations):
#   I·the_cancellation_table_exists_with_one_row_per_reservation_of_a_departure   AC-DB-07.1, -07.3
#   I·a_cancellation_has_its_bounded_justification                               AC-DB-07.2
#   I·a_cancellation_belongs_to_a_departure_of_its_tenant                        AC-DB-07.4
#   I·the_application_user_records_but_never_changes_a_cancellation              AC-DB-07.6
# Checks of spec 009 (HU-OPS-008, the personal emergencies):
#   I·the_emergency_table_exists_with_one_row_per_reservation_of_a_departure   AC-DB-09.1, -09.3
#   I·an_emergency_has_its_bounded_detail_and_at_least_one_traveler          AC-DB-09.2
#   I·an_emergency_belongs_to_a_departure_of_its_tenant                      AC-DB-09.4
#   I·the_application_user_records_but_never_changes_an_emergency            AC-DB-09.6
# Checks of spec 008 (HU-OPS-006, the cancellation of a departure):
#   I·the_cancellation_columns_exist_and_an_old_departure_has_none         AC-DB-08.1
#   I·a_cancelled_departure_has_its_instant_and_cause_and_only_it          AC-DB-08.2
#   I·the_cause_and_the_reason_agree_and_the_reason_is_bounded             AC-DB-08.3
#   I·a_cancellation_is_never_rewritten                                    AC-DB-08.4
#   I·the_application_user_cancels_a_departure_and_never_deletes_one       AC-DB-08.6
# Checks of spec 004 (HU-OPS-003 part B, the mark and the regularization):
#   I·the_regularization_columns_exist_and_an_old_departure_has_none     AC-DB-04.1
#   I·the_mark_needs_its_moment_and_only_marks_an_open_departure         AC-DB-04.2
#   I·who_regularized_and_when_go_together_on_a_finished_departure       AC-DB-04.3
#   I·an_early_start_reason_is_of_a_regularization_and_up_to_500         AC-DB-04.4
#   I·the_departures_past_their_end_are_found_through_a_partial_index    AC-DB-04.5
#   I·the_application_user_marks_and_regularizes                         AC-DB-04.7
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
  extra_cols=""; extra_vals=""
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      id) id=$v ;; tenant) tenant=$v ;; code) code=$v ;; service) service=$v ;; starts) starts=$v ;;
      ends) ends=$v ;; zone) zone=$v ;; status) status=$v ;; by) by=$v ;; at) at=$v ;;
      actual_start_at|started_by|actual_end_at|finished_by|interrupted|interruption_cause|pending_regularization|pending_marked_at|regularized_by|regularized_at|early_start_reason|cancelled_at|cancelled_by|cancellation_cause|cancellation_reason)
        extra_cols="$extra_cols, ${kv%%=*}"; extra_vals="$extra_vals, $v" ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida (salida_id, tenant_id, code, service_id, starts_at, estimated_end_at, time_zone, status, scheduled_by, scheduled_at%s) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s%s)" \
    "$extra_cols" "$id" "$tenant" "$code" "$service" "$starts" "$ends" "$zone" "$status" "$by" "$at" "$extra_vals"
}
# the execution columns a departure in that state needs (spec 003): a start for one in execution, and an end for a finished one
STARTED="actual_start_at='2026-12-01 08:05:00+00'"
ENDED="actual_end_at='2026-12-01 17:30:00+00'"
# the key table references the departures, so both are truncated together
# (the vehicle tables are included when they exist, so the checks of spec 001 also run on a schema without them)
clean_departures() {
  tables=$(psql_admin -c "SELECT string_agg(format('%I.%I', schemaname, tablename), ',') FROM pg_tables
    WHERE schemaname = '$SCHEMA' AND tablename IN ('idempotency_key', 'salida', 'salida_vehicle', 'vehicle', 'vehicle_idempotency_key', 'salida_service', 'salida_cost', 'salida_extraordinary_cancellation', 'salida_personal_emergency')")
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
    case $status in
      IN_EXECUTION) set -- "$STARTED" "started_by='$ACTOR'" ;;
      FINISHED) set -- "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" ;;
      CANCELLED) set -- "cancelled_at='2026-12-01 09:00:00+00'" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'" ;;
      *) set -- ;;
    esac
    psql_admin -c "$(departure "code='SAL-0$n'" "status='$status'" "$@")" >/dev/null || { echo "the state $status was refused"; return 1; }
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
  psql_app -c "UPDATE operations_cost.salida SET time_zone = 'America/Lima'" >/dev/null || { echo "the application user cannot update a departure"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.salida" 2>&1) && { echo "the application user deleted a departure"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM operations_cost.salida")" = 1 ] || { echo "the departure is gone"; return 1; }
}

# ---- the probes of the real start and end (spec 003, HU-OPS-003)
the_execution_columns_exist_and_an_old_departure_is_not_interrupted() {
  clean_departures || return 1
  cols=$(psql_admin -c "SELECT string_agg(column_name || ':' || is_nullable, ',' ORDER BY column_name) FROM information_schema.columns
    WHERE table_schema = 'operations_cost' AND table_name = 'salida' AND column_name IN ('actual_start_at', 'started_by',
    'actual_end_at', 'finished_by', 'interrupted', 'interruption_cause', 'pending_regularization')")
  [ "$cols" = "actual_end_at:YES,actual_start_at:YES,finished_by:YES,interrupted:NO,interruption_cause:YES,pending_regularization:NO,started_by:YES" ] \
    || { echo "the execution columns are not as the plan says: '$cols'"; return 1; }
  psql_admin -c "$(departure)" >/dev/null || { echo "a departure without execution was refused"; return 1; }
  [ "$(psql_admin -c "SELECT interrupted, pending_regularization, actual_start_at IS NULL FROM operations_cost.salida")" = "f|f|t" ] \
    || { echo "a departure without execution is not 'not interrupted, not marked, not started'"; return 1; }
}
a_start_goes_with_the_execution_and_who_recorded_it() {
  clean_departures || return 1
  refused chk_salida_execution_start "$(departure "status='IN_EXECUTION'")" || return 1
  refused chk_salida_execution_start "$(departure "status='IN_EXECUTION'" "$STARTED")" || return 1
  refused chk_salida_execution_start "$(departure "$STARTED" "started_by='$ACTOR'")" || return 1
  psql_admin -c "$(departure "status='IN_EXECUTION'" "$STARTED" "started_by='$ACTOR'")" >/dev/null || { echo "a departure in execution with its start was refused"; return 1; }
}
an_end_goes_with_a_finished_departure_after_its_start() {
  clean_departures || return 1
  refused chk_salida_execution_end "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'")" || return 1
  refused chk_salida_execution_end "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED")" || return 1
  refused chk_salida_execution_end "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "actual_end_at='2026-12-01 08:04:59+00'" "finished_by='$ACTOR'")" || return 1
  refused chk_salida_execution_end "$(departure "status='IN_EXECUTION'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'")" || return 1
  psql_admin -c "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'")" >/dev/null || { echo "a finished departure with its start and end was refused"; return 1; }
}
an_interruption_finishes_the_departure_with_its_cause() {
  clean_departures || return 1
  refused chk_salida_interruption "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "interrupted=true")" || return 1
  refused chk_salida_interruption "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "interruption_cause='Lluvia'")" || return 1
  refused chk_salida_interruption "$(departure "status='IN_EXECUTION'" "$STARTED" "started_by='$ACTOR'" "interrupted=true" "interruption_cause='Lluvia'")" || return 1
  refused chk_salida_interruption "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "interrupted=true" "interruption_cause=''")" || return 1
  refused chk_salida_interruption "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "interrupted=true" "interruption_cause=repeat('x',1001)")" || return 1
  psql_admin -c "$(departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "interrupted=true" "interruption_cause=repeat('x',1000)")" >/dev/null \
    || { echo "an interrupted departure with a cause of 1000 characters was refused"; return 1; }
}
the_application_user_records_the_execution() {
  clean_departures || return 1
  psql_admin -c "$(departure)" >/dev/null || return 1
  psql_app -c "UPDATE operations_cost.salida SET status = 'IN_EXECUTION', actual_start_at = now(), started_by = '$ACTOR'" >/dev/null \
    || { echo "the application user cannot record a start"; return 1; }
  psql_app -c "UPDATE operations_cost.salida SET status = 'FINISHED', actual_end_at = now(), finished_by = '$ACTOR', interrupted = true, interruption_cause = 'Lluvia'" >/dev/null \
    || { echo "the application user cannot record an interrupted end"; return 1; }
}

# ---- the probes of the mark and the regularization (spec 004, HU-OPS-003 part B)
MARKED="pending_marked_at='2026-12-01 18:15:00+00'"
REG_BY="regularized_by='$ACTOR'"
REG_AT="regularized_at='2026-12-02 09:00:00+00'"
finished() { # [column=value ...]: a finished departure with its start and end, regularized as given
  departure "status='FINISHED'" "$STARTED" "started_by='$ACTOR'" "$ENDED" "finished_by='$ACTOR'" "$@"
}
the_regularization_columns_exist_and_an_old_departure_has_none() {
  clean_departures || return 1
  cols=$(psql_admin -c "SELECT string_agg(column_name || ':' || is_nullable, ',' ORDER BY column_name) FROM information_schema.columns
    WHERE table_schema = 'operations_cost' AND table_name = 'salida' AND column_name IN ('pending_marked_at', 'regularized_by',
    'regularized_at', 'early_start_reason')")
  [ "$cols" = "early_start_reason:YES,pending_marked_at:YES,regularized_at:YES,regularized_by:YES" ]     || { echo "the regularization columns are not as the plan says: '$cols'"; return 1; }
  psql_admin -c "$(departure)" >/dev/null || { echo "a departure without regularization was refused"; return 1; }
  [ "$(psql_admin -c "SELECT pending_marked_at IS NULL, regularized_by IS NULL, regularized_at IS NULL, early_start_reason IS NULL FROM operations_cost.salida")" = "t|t|t|t" ]     || { echo "a departure without regularization has a value in a new column"; return 1; }
}
the_mark_needs_its_moment_and_only_marks_an_open_departure() {
  clean_departures || return 1
  refused chk_salida_pending_mark "$(departure "pending_regularization=true")" || return 1
  refused chk_salida_pending_mark "$(finished "pending_regularization=true" "$MARKED")" || return 1
  psql_admin -c "$(departure "pending_regularization=true" "$MARKED")" >/dev/null || { echo "a scheduled departure with its mark was refused"; return 1; }
  psql_admin -c "$(finished "$MARKED" "code='SAL-002'")" >/dev/null || { echo "a finished departure keeping the moment of its mark was refused"; return 1; }
}
who_regularized_and_when_go_together_on_a_finished_departure() {
  clean_departures || return 1
  refused chk_salida_regularization "$(finished "regularized_by='$ACTOR'")" || return 1
  refused chk_salida_regularization "$(finished "regularized_at='2026-12-02 09:00:00+00'")" || return 1
  refused chk_salida_regularization "$(departure "$REG_BY" "$REG_AT")" || return 1
  psql_admin -c "$(finished "$REG_BY" "$REG_AT")" >/dev/null || { echo "a finished departure with who and when was refused"; return 1; }
}
an_early_start_reason_is_of_a_regularization_and_up_to_500() {
  clean_departures || return 1
  refused chk_salida_early_start_reason "$(finished "early_start_reason='Salio temprano'")" || return 1
  refused chk_salida_early_start_reason "$(finished "$REG_BY" "$REG_AT" "early_start_reason=''")" || return 1
  refused chk_salida_early_start_reason "$(finished "$REG_BY" "$REG_AT" "early_start_reason=repeat('x',501)")" || return 1
  psql_admin -c "$(finished "$REG_BY" "$REG_AT" "early_start_reason=repeat('x',500)")" >/dev/null || { echo "a reason of 500 characters was refused"; return 1; }
}
the_departures_past_their_end_are_found_through_a_partial_index() {
  clean_departures || return 1
  def=$(psql_admin -c "SELECT indexdef FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_salida_open_past_end'")
  printf '%s' "$def" | grep -q "estimated_end_at" && printf '%s' "$def" | grep -q "WHERE"     || { echo "idx_salida_open_past_end is not a partial index of estimated_end_at: '$def'"; return 1; }
  plan=$(psql_admin -c "SET enable_seqscan = off; EXPLAIN SELECT salida_id FROM operations_cost.salida WHERE status IN ('SCHEDULED', 'IN_EXECUTION') AND NOT pending_regularization AND estimated_end_at <= now() ORDER BY estimated_end_at LIMIT 100")
  printf '%s' "$plan" | grep -q "idx_salida_open_past_end" || { echo "the search of job 3 does not use the partial index: $plan"; return 1; }
}
the_application_user_marks_and_regularizes() {
  clean_departures || return 1
  psql_admin -c "$(departure)" >/dev/null || return 1
  psql_app -c "UPDATE operations_cost.salida SET pending_regularization = true, pending_marked_at = now()" >/dev/null     || { echo "the application user cannot mark"; return 1; }
  psql_app -c "UPDATE operations_cost.salida SET status = 'FINISHED', pending_regularization = false, actual_start_at = now() - interval '2 hours', started_by = '$ACTOR', actual_end_at = now(), finished_by = '$ACTOR', regularized_by = '$ACTOR', regularized_at = now(), early_start_reason = 'Salio antes'" >/dev/null     || { echo "the application user cannot regularize"; return 1; }
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
  for idx in vehicle_id salida_id; do
    def=$(psql_admin -c "SELECT indexdef FROM pg_indexes WHERE schemaname = 'operations_cost' AND indexname = 'idx_salida_vehicle_tenant_id_$idx'")
    case "$def" in
      *"(tenant_id, $idx)"*) ;;
      *) echo "the index of the foreign key must be on (tenant_id, $idx): '$def'"; return 1 ;;
    esac
  done
  # the service reads, adds and (part B) will remove assignments, never deletes a vehicle
  psql_admin -c "$(vehicle "id='$V2'" "name='Van 2'")" >/dev/null || return 1
  psql_app -c "$(assignment $S1 $V2)" >/dev/null || { echo "the application user cannot add an assignment"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.salida_vehicle")" = 2 ] || { echo "the application user cannot read the assignments"; return 1; }
}
the_application_user_deletes_an_assignment_and_never_a_vehicle() {
  clean_departures || return 1
  S1=00000000-0000-4000-8000-0000000000f1
  psql_admin -c "$(departure "id='$S1'")" >/dev/null || return 1
  psql_admin -c "$(vehicle)" >/dev/null || return 1
  psql_admin -c "$(assignment $S1 $V1)" >/dev/null || return 1
  psql_app -c "DELETE FROM operations_cost.salida_vehicle" >/dev/null || { echo "the application user cannot take a vehicle off a departure"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM operations_cost.salida_vehicle")" = 0 ] || { echo "the assignment is still there"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.vehicle" 2>&1) && { echo "the application user deleted a vehicle"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
}

vehicle_key() { # scope, key, vehicle id
  printf "INSERT INTO operations_cost.vehicle_idempotency_key (scope, idempotency_key, vehicle_id) VALUES ('%s', '%s', '%s')" "$1" "$2" "$3"
}
a_vehicle_key_is_unique_8_to_128_characters_and_points_to_its_vehicle() {
  clean_departures || return 1
  psql_admin -c "$(vehicle)" >/dev/null || return 1
  psql_admin -c "$(vehicle_key createVehicle/$T1 abcdefgh $V1)" >/dev/null || { echo "a valid key was refused"; return 1; }
  refused pk_vehicle_idempotency_key "$(vehicle_key createVehicle/$T1 abcdefgh $V1)" || return 1
  psql_admin -c "$(vehicle_key createVehicle/$T2 abcdefgh $V1)" >/dev/null || { echo "the same key in another scope was refused"; return 1; }
  refused chk_vehicle_idempotency_key_length "$(vehicle_key createVehicle/$T1 abcdefg $V1)" || return 1
  refused chk_vehicle_idempotency_key_length "$(vehicle_key createVehicle/$T1 "$(printf 'k%.0s' $(seq 1 129))" $V1)" || return 1
  refused fk_vehicle_idempotency_key_vehicle "$(vehicle_key createVehicle/$T1 hgfedcba 00000000-0000-4000-8000-0000000000ff)" || return 1
  refused fk_vehicle_idempotency_key_vehicle "DELETE FROM operations_cost.vehicle WHERE vehicle_id = '$V1'" || return 1
  psql_app -c "$(vehicle_key createVehicle/$T1 appkey001 $V1)" >/dev/null || { echo "the application user cannot write a vehicle key"; return 1; }
}

service() { # salida id, reservation id, [column=value ...]: the record of a reservation of a departure, valid unless overridden
  sid=$1; rid=$2; shift 2
  tenant="'$T1'"; result="'DELIVERED'"; served=2; cause="NULL"; noshow=false; by="'$ACTOR'"; at="now()"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      tenant) tenant=$v ;; result) result=$v ;; served) served=$v ;; cause) cause=$v ;; noshow) noshow=$v ;; by) by=$v ;; at) at=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida_service (tenant_id, salida_id, reservation_id, result, travelers_served, cause, no_show, recorded_by, recorded_at) VALUES (%s, '%s', '%s', %s, %s, %s, %s, %s, %s)"     "$tenant" "$sid" "$rid" "$result" "$served" "$cause" "$noshow" "$by" "$at"
}
S1=00000000-0000-4000-8000-0000000000a1
R1=00000000-0000-4000-8000-0000000000b1
R2=00000000-0000-4000-8000-0000000000b2
a_running_departure() { clean_departures || return 1; psql_admin -c "$(departure "id='$S1'" "status='IN_EXECUTION'" "$STARTED" "started_by='$ACTOR'")" >/dev/null || { echo "could not insert a departure"; return 1; }; }
the_service_table_exists_with_one_row_per_reservation_of_a_departure() {
  a_running_departure || return 1
  psql_admin -c "$(service $S1 $R1)" >/dev/null || { echo "a valid record was refused"; return 1; }
  psql_admin -c "$(service $S1 $R2)" >/dev/null || { echo "a second reservation of the same departure was refused"; return 1; }
  refused pk_salida_service "$(service $S1 $R1)" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = '$SCHEMA' AND table_name = 'salida_service'")" = 9 ] || { echo "the table does not have the nine columns"; return 1; }
}
a_result_and_its_travelers_served_agree() {
  a_running_departure || return 1
  refused chk_salida_service_result "$(service $S1 $R1 "result='MAYBE'")" || return 1
  refused chk_salida_service_travelers "$(service $S1 $R1 served=-1)" || return 1
  refused chk_salida_service_travelers "$(service $S1 $R1 "result='NOT_DELIVERED'" served=1 "cause='did not come'")" || return 1
  refused chk_salida_service_travelers "$(service $S1 $R1 served=0)" || return 1
  psql_admin -c "$(service $S1 $R1 "result='NOT_DELIVERED'" served=0 "cause='did not come'")" >/dev/null || { echo "a valid undelivered record was refused"; return 1; }
}
an_undelivered_service_has_its_cause_and_a_no_show_is_undelivered() {
  a_running_departure || return 1
  refused chk_salida_service_cause "$(service $S1 $R1 "result='NOT_DELIVERED'" served=0)" || return 1
  refused chk_salida_service_cause "$(service $S1 $R1 "result='NOT_DELIVERED'" served=0 "cause=''")" || return 1
  refused chk_salida_service_cause "$(service $S1 $R1 "result='NOT_DELIVERED'" served=0 "cause='$(printf 'c%.0s' $(seq 1 501))'")" || return 1
  refused chk_salida_service_no_show "$(service $S1 $R1 noshow=true)" || return 1
  psql_admin -c "$(service $S1 $R1 "result='NOT_DELIVERED'" served=0 "cause='no notice'" noshow=true)" >/dev/null || { echo "a valid no-show was refused"; return 1; }
  psql_admin -c "$(service $S1 $R2 served=1 "cause='one traveler stayed'")" >/dev/null || { echo "a partial delivery with its cause was refused"; return 1; }
}
a_service_belongs_to_a_departure_of_its_tenant() {
  a_running_departure || return 1
  refused fk_salida_service_salida "$(service 00000000-0000-4000-8000-0000000000ff $R1)" || return 1
  refused fk_salida_service_salida "$(service $S1 $R1 "tenant='$T2'")" || return 1
  psql_admin -c "$(service $S1 $R1)" >/dev/null || return 1
  refused fk_salida_service_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$S1'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = '$SCHEMA' AND tablename = 'salida_service' AND indexname = 'idx_salida_service_tenant_id_salida_id'")" = 1 ] || { echo "the index of the key is missing"; return 1; }
}
the_application_user_records_but_never_deletes_a_service() {
  a_running_departure || return 1
  psql_app -c "$(service $S1 $R1)" >/dev/null || { echo "the application user cannot insert a record"; return 1; }
  psql_app -c "UPDATE operations_cost.salida_service SET travelers_served = 1, recorded_at = now()" >/dev/null || { echo "the application user cannot replace a record"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.salida_service" 2>&1) && { echo "the application user deleted a record"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
}

cost() { # [column=value ...]: a cost line of the departure S1, a real expense unless overridden
  tenant="'$T1'"; sid="'$S1'"; concept="'Fuel of the boat'"; amount=50000; mode="'MANUAL'"; unit="NULL"; served="NULL"
  wop=false; just="NULL"; key="gen_random_uuid()::text"; by="'$ACTOR'"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      tenant) tenant=$v ;; sid) sid=$v ;; concept) concept=$v ;; amount) amount=$v ;; mode) mode=$v ;; unit) unit=$v ;; served) served=$v ;;
      wop) wop=$v ;; just) just=$v ;; key) key=$v ;; by) by=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida_cost (cost_id, tenant_id, salida_id, concept, amount_cents, mode, unit_cost_cents, travelers_served, without_parametrization, justification, idempotency_key, recorded_by, recorded_at) VALUES (gen_random_uuid(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, now())" \
    "$tenant" "$sid" "$concept" "$amount" "$mode" "$unit" "$served" "$wop" "$just" "$key" "$by"
}
the_cost_table_keeps_many_lines_per_departure() {
  a_running_departure || return 1
  psql_admin -c "$(cost)" >/dev/null || { echo "a valid cost was refused"; return 1; }
  psql_admin -c "$(cost)" >/dev/null || { echo "a second cost of the same departure was refused"; return 1; }
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = '$SCHEMA' AND table_name = 'salida_cost'")" = 13 ] || { echo "the table does not have the thirteen columns"; return 1; }
}
a_cost_needs_a_concept_and_an_amount_above_zero() {
  a_running_departure || return 1
  refused chk_salida_cost_concept "$(cost "concept=''")" || return 1
  refused chk_salida_cost_concept "$(cost "concept='$(printf 'c%.0s' $(seq 1 201))'")" || return 1
  refused chk_salida_cost_amount "$(cost amount=0)" || return 1
  refused chk_salida_cost_amount "$(cost amount=-5)" || return 1
  psql_admin -c "$(cost "concept='$(printf 'c%.0s' $(seq 1 200))'")" >/dev/null || { echo "a concept of 200 characters was refused"; return 1; }
}
a_calculated_cost_is_the_unit_cost_times_the_travelers_and_a_manual_one_has_neither() {
  a_running_departure || return 1
  psql_admin -c "$(cost "mode='CALCULATED'" unit=1000 served=3 amount=3000)" >/dev/null || { echo "a valid calculated cost was refused"; return 1; }
  refused chk_salida_cost_calculation "$(cost "mode='CALCULATED'" unit=1000 served=3 amount=2999)" || return 1
  refused chk_salida_cost_calculation "$(cost "mode='CALCULATED'" unit=1000 served=0 amount=1000)" || return 1
  refused chk_salida_cost_calculation "$(cost "mode='CALCULATED'" served=3 amount=3000)" || return 1
  refused chk_salida_cost_calculation "$(cost "mode='CALCULATED'" unit=1000 amount=1000)" || return 1
  refused chk_salida_cost_calculation "$(cost unit=1000)" || return 1
  refused chk_salida_cost_calculation "$(cost served=3)" || return 1
  refused chk_salida_cost "$(cost "mode='OTHER'")" || return 1
}
a_cost_without_a_catalogued_cost_is_manual_and_justified() {
  a_running_departure || return 1
  psql_admin -c "$(cost wop=true "just='No catalogued cost, paid at the dock'")" >/dev/null || { echo "a justified cost without parametrization was refused"; return 1; }
  refused chk_salida_cost_justification "$(cost wop=true)" || return 1
  refused chk_salida_cost_justification "$(cost wop=true "just=''")" || return 1
  refused chk_salida_cost_justification "$(cost wop=true "just='$(printf 'j%.0s' $(seq 1 501))'")" || return 1
  refused chk_salida_cost_justification "$(cost "just='a justification with a catalogued cost'")" || return 1
  refused chk_salida_cost_justification "$(cost "mode='CALCULATED'" unit=1000 served=3 amount=3000 wop=true "just='x'")" || return 1
}
a_cost_belongs_to_a_departure_of_its_tenant() {
  a_running_departure || return 1
  refused fk_salida_cost_salida "$(cost "sid='00000000-0000-4000-8000-0000000000ff'")" || return 1
  refused fk_salida_cost_salida "$(cost "tenant='$T2'")" || return 1
  psql_admin -c "$(cost)" >/dev/null || return 1
  refused fk_salida_cost_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$S1'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = '$SCHEMA' AND tablename = 'salida_cost' AND indexname = 'idx_salida_cost_tenant_id_salida_id'")" = 1 ] || { echo "the index of the key is missing"; return 1; }
}
a_cost_key_is_unique_in_a_tenant_and_8_to_128_characters() {
  a_running_departure || return 1
  psql_admin -c "$(cost "key='cost-key-0001'")" >/dev/null || { echo "a valid key was refused"; return 1; }
  refused uq_salida_cost_tenant_key "$(cost "key='cost-key-0001'")" || return 1
  refused chk_salida_cost_key_length "$(cost "key='abcdefg'")" || return 1
  refused chk_salida_cost_key_length "$(cost "key='$(printf 'k%.0s' $(seq 1 129))'")" || return 1
}
the_application_user_records_but_never_changes_a_cost() {
  a_running_departure || return 1
  psql_app -c "$(cost)" >/dev/null || { echo "the application user cannot insert a cost"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.salida_cost")" = 1 ] || { echo "the application user cannot read a cost"; return 1; }
  for statement in "UPDATE operations_cost.salida_cost SET amount_cents = 1" "DELETE FROM operations_cost.salida_cost"; do
    out=$(psql_app -c "$statement" 2>&1) && { echo "the application user changed a cost: $statement"; return 1; }
    printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  done
}

xcancel() { # salida id, reservation id, [column=value ...]: an extraordinary cancellation, valid unless overridden
  sid=$1; rid=$2; shift 2
  tenant="'$T1'"; just="'emergency of the traveler'"; by="'$ACTOR'"; at="now()"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      tenant) tenant=$v ;; just) just=$v ;; by) by=$v ;; at) at=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida_extraordinary_cancellation (tenant_id, salida_id, reservation_id, justification, recorded_by, recorded_at) VALUES (%s, '%s', '%s', %s, %s, %s)"     "$tenant" "$sid" "$rid" "$just" "$by" "$at"
}
the_cancellation_table_exists_with_one_row_per_reservation_of_a_departure() {
  a_running_departure || return 1
  psql_admin -c "$(xcancel $S1 $R1)" >/dev/null || { echo "a valid cancellation was refused"; return 1; }
  psql_admin -c "$(xcancel $S1 $R2)" >/dev/null || { echo "a second reservation of the same departure was refused"; return 1; }
  refused pk_salida_extraordinary_cancellation "$(xcancel $S1 $R1)" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = '$SCHEMA' AND table_name = 'salida_extraordinary_cancellation'")" = 6 ] || { echo "the table does not have the six columns"; return 1; }
}
a_cancellation_has_its_bounded_justification() {
  a_running_departure || return 1
  refused chk_salida_extraordinary_cancellation_justification "$(xcancel $S1 $R1 "just=''")" || return 1
  refused chk_salida_extraordinary_cancellation_justification "$(xcancel $S1 $R1 "just='$(printf 'j%.0s' $(seq 1 501))'")" || return 1
  refused salida_extraordinary_cancellation "$(xcancel $S1 $R1 just=NULL)" || return 1
  psql_admin -c "$(xcancel $S1 $R1 "just='$(printf 'j%.0s' $(seq 1 500))'")" >/dev/null || { echo "a justification of 500 was refused"; return 1; }
}
a_cancellation_belongs_to_a_departure_of_its_tenant() {
  a_running_departure || return 1
  refused fk_salida_extraordinary_cancellation_salida "$(xcancel 00000000-0000-4000-8000-0000000000ff $R1)" || return 1
  refused fk_salida_extraordinary_cancellation_salida "$(xcancel $S1 $R1 "tenant='$T2'")" || return 1
  psql_admin -c "$(xcancel $S1 $R1)" >/dev/null || return 1
  refused fk_salida_extraordinary_cancellation_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$S1'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = '$SCHEMA' AND tablename = 'salida_extraordinary_cancellation' AND indexname = 'idx_salida_extraordinary_cancellation_tenant_id_salida_id'")" = 1 ] || { echo "the index of the key is missing"; return 1; }
}
the_application_user_records_but_never_changes_a_cancellation() {
  a_running_departure || return 1
  psql_app -c "$(xcancel $S1 $R1)" >/dev/null || { echo "the application user cannot insert a cancellation"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.salida_extraordinary_cancellation")" = 1 ] || { echo "the application user cannot read a cancellation"; return 1; }
  for statement in "UPDATE operations_cost.salida_extraordinary_cancellation SET justification = 'x'" "DELETE FROM operations_cost.salida_extraordinary_cancellation"; do
    out=$(psql_app -c "$statement" 2>&1) && { echo "the application user changed a cancellation: $statement"; return 1; }
    printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  done
}

pemergency() { # salida id, reservation id, [column=value ...]: a personal emergency, valid unless overridden
  sid=$1; rid=$2; shift 2
  tenant="'$T1'"; travelers=2; detail="'a traveler fainted on the trail'"; by="'$ACTOR'"; at="now()"
  for kv in "$@"; do
    v=${kv#*=}
    case ${kv%%=*} in
      tenant) tenant=$v ;; travelers) travelers=$v ;; detail) detail=$v ;; by) by=$v ;; at) at=$v ;;
      *) printf 'UNKNOWN_OVERRIDE_%s' "${kv%%=*}"; return 0 ;;
    esac
  done
  printf "INSERT INTO operations_cost.salida_personal_emergency (tenant_id, salida_id, reservation_id, affected_travelers, detail, recorded_by, recorded_at) VALUES (%s, '%s', '%s', %s, %s, %s, %s)" "$tenant" "$sid" "$rid" "$travelers" "$detail" "$by" "$at"
}
the_emergency_table_exists_with_one_row_per_reservation_of_a_departure() {
  a_running_departure || return 1
  psql_admin -c "$(pemergency $S1 $R1)" >/dev/null || { echo "a valid emergency was refused"; return 1; }
  psql_admin -c "$(pemergency $S1 $R2)" >/dev/null || { echo "a second reservation of the same departure was refused"; return 1; }
  refused pk_salida_personal_emergency "$(pemergency $S1 $R1)" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM information_schema.columns WHERE table_schema = '$SCHEMA' AND table_name = 'salida_personal_emergency'")" = 7 ] || { echo "the table does not have the seven columns"; return 1; }
}
an_emergency_has_its_bounded_detail_and_at_least_one_traveler() {
  a_running_departure || return 1
  refused chk_salida_personal_emergency_detail "$(pemergency $S1 $R1 "detail=''")" || return 1
  refused chk_salida_personal_emergency_detail "$(pemergency $S1 $R1 "detail='$(printf 'd%.0s' $(seq 1 1001))'")" || return 1
  refused salida_personal_emergency "$(pemergency $S1 $R1 detail=NULL)" || return 1
  refused chk_salida_personal_emergency_affected_travelers "$(pemergency $S1 $R1 travelers=0)" || return 1
  refused salida_personal_emergency "$(pemergency $S1 $R1 travelers=NULL)" || return 1
  psql_admin -c "$(pemergency $S1 $R1 "detail='$(printf 'd%.0s' $(seq 1 1000))'" travelers=1)" >/dev/null || { echo "a detail of 1000 with one traveler was refused"; return 1; }
}
an_emergency_belongs_to_a_departure_of_its_tenant() {
  a_running_departure || return 1
  refused fk_salida_personal_emergency_salida "$(pemergency 00000000-0000-4000-8000-0000000000ff $R1)" || return 1
  refused fk_salida_personal_emergency_salida "$(pemergency $S1 $R1 "tenant='$T2'")" || return 1
  psql_admin -c "$(pemergency $S1 $R1)" >/dev/null || return 1
  refused fk_salida_personal_emergency_salida "DELETE FROM operations_cost.salida WHERE salida_id = '$S1'" || return 1
  [ "$(psql_admin -c "SELECT count(*) FROM pg_indexes WHERE schemaname = '$SCHEMA' AND tablename = 'salida_personal_emergency' AND indexname = 'idx_salida_personal_emergency_tenant_id_salida_id'")" = 1 ] || { echo "the index of the key is missing"; return 1; }
}
the_application_user_records_but_never_changes_an_emergency() {
  a_running_departure || return 1
  psql_app -c "$(pemergency $S1 $R1)" >/dev/null || { echo "the application user cannot insert an emergency"; return 1; }
  [ "$(psql_app -c "SELECT count(*) FROM operations_cost.salida_personal_emergency")" = 1 ] || { echo "the application user cannot read an emergency"; return 1; }
  for statement in "UPDATE operations_cost.salida_personal_emergency SET detail = 'x'" "DELETE FROM operations_cost.salida_personal_emergency"; do
    out=$(psql_app -c "$statement" 2>&1) && { echo "the application user changed an emergency: $statement"; return 1; }
    printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
  done
}

CANCELLED_AT="cancelled_at='2026-12-01 09:00:00+00'"
the_cancellation_columns_exist_and_an_old_departure_has_none() {
  clean_departures || return 1
  cols=$(psql_admin -c "SELECT string_agg(column_name || ':' || is_nullable, ',' ORDER BY column_name) FROM information_schema.columns
    WHERE table_schema = 'operations_cost' AND table_name = 'salida' AND column_name IN ('cancelled_at', 'cancelled_by',
    'cancellation_cause', 'cancellation_reason')")
  [ "$cols" = "cancellation_cause:YES,cancellation_reason:YES,cancelled_at:YES,cancelled_by:YES" ] \
    || { echo "the cancellation columns are not as the plan says: '$cols'"; return 1; }
  psql_admin -c "$(departure)" >/dev/null || { echo "a departure that was never cancelled was refused"; return 1; }
  [ "$(psql_admin -c "SELECT cancelled_at IS NULL, cancelled_by IS NULL, cancellation_cause IS NULL, cancellation_reason IS NULL FROM operations_cost.salida")" = "t|t|t|t" ] \
    || { echo "a departure that was never cancelled has a value in a new column"; return 1; }
}
a_cancelled_departure_has_its_instant_and_cause_and_only_it() {
  clean_departures || return 1
  refused chk_salida_cancellation "$(departure "status='CANCELLED'")" || return 1
  refused chk_salida_cancellation "$(departure "status='CANCELLED'" "$CANCELLED_AT")" || return 1
  refused chk_salida_cancellation "$(departure "status='CANCELLED'" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'")" || return 1
  refused chk_salida_cancellation "$(departure "$CANCELLED_AT" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'")" || return 1
  refused chk_salida_cancellation "$(departure "cancelled_by='$ACTOR'")" || return 1
  psql_admin -c "$(departure "status='CANCELLED'" "$CANCELLED_AT" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'")" >/dev/null \
    || { echo "a cancellation by the system was refused"; return 1; }
  psql_admin -c "$(departure "code='SAL-002'" "status='CANCELLED'" "$CANCELLED_AT" "cancelled_by='$ACTOR'" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'")" >/dev/null \
    || { echo "a cancellation by a person was refused"; return 1; }
}
the_cause_and_the_reason_agree_and_the_reason_is_bounded() {
  clean_departures || return 1
  base="status='CANCELLED'"
  refused chk_salida_cancellation_cause "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='OTHER'")" || return 1
  refused chk_salida_cancellation_reason "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='NOT_CARRIED_OUT'")" || return 1
  refused chk_salida_cancellation_reason "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='NOT_CARRIED_OUT'" "cancellation_reason=''")" || return 1
  refused chk_salida_cancellation_reason "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='NOT_CARRIED_OUT'" "cancellation_reason='$(printf 'r%.0s' $(seq 1 501))'")" || return 1
  refused chk_salida_cancellation_reason "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='NOT_ATTRIBUTABLE_TO_CUSTOMER'" "cancellation_reason='a reason'")" || return 1
  psql_admin -c "$(departure "$base" "$CANCELLED_AT" "cancellation_cause='NOT_CARRIED_OUT'" "cancellation_reason='$(printf 'r%.0s' $(seq 1 500))'")" >/dev/null \
    || { echo "a reason of 500 characters was refused"; return 1; }
}
a_cancellation_is_never_rewritten() {
  clean_departures || return 1
  psql_admin -c "$(departure "id='$S1'" "status='CANCELLED'" "$CANCELLED_AT" "cancellation_cause='NOT_CARRIED_OUT'" "cancellation_reason='nobody came'")" >/dev/null || return 1
  refused "a cancellation is final" "UPDATE operations_cost.salida SET cancelled_at = cancelled_at + interval '1 minute' WHERE salida_id = '$S1'" || return 1
  refused "a cancellation is final" "UPDATE operations_cost.salida SET cancellation_cause = 'NOT_ATTRIBUTABLE_TO_CUSTOMER', cancellation_reason = NULL WHERE salida_id = '$S1'" || return 1
  refused "a cancellation is final" "UPDATE operations_cost.salida SET cancellation_reason = 'another reason' WHERE salida_id = '$S1'" || return 1
  refused chk_salida_cancellation "UPDATE operations_cost.salida SET status = 'SCHEDULED' WHERE salida_id = '$S1'" || return 1
  # the refusal has a code the service can tell apart from any other raised exception: a check violation (23514)
  out=$(psql_admin -c "DO \$\$ BEGIN UPDATE operations_cost.salida SET cancellation_reason = 'again' WHERE salida_id = '$S1'; EXCEPTION WHEN check_violation THEN RAISE EXCEPTION 'caught_check_violation'; END \$\$" 2>&1)     || printf '%s' "$out" | grep -q caught_check_violation || { echo "the rewrite of a cancellation is not refused with a check violation: $out"; return 1; }
}
the_application_user_cancels_a_departure_and_never_deletes_one() {
  clean_departures || return 1
  psql_admin -c "$(departure "id='$S1'")" >/dev/null || return 1
  psql_app -c "UPDATE operations_cost.salida SET status = 'CANCELLED', cancelled_at = now(), cancellation_cause = 'NOT_ATTRIBUTABLE_TO_CUSTOMER' WHERE salida_id = '$S1' AND status = 'SCHEDULED'" >/dev/null \
    || { echo "the application user cannot cancel a departure"; return 1; }
  out=$(psql_app -c "DELETE FROM operations_cost.salida" 2>&1) && { echo "the application user deleted a departure"; return 1; }
  printf '%s' "$out" | grep -q "permission denied" || { echo "refused, but not for a missing privilege: $out"; return 1; }
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
check "I·the_application_user_deletes_an_assignment_and_never_a_vehicle" the_application_user_deletes_an_assignment_and_never_a_vehicle
check "I·a_vehicle_key_is_unique_8_to_128_characters_and_points_to_its_vehicle" a_vehicle_key_is_unique_8_to_128_characters_and_points_to_its_vehicle
check "I·the_execution_columns_exist_and_an_old_departure_is_not_interrupted" the_execution_columns_exist_and_an_old_departure_is_not_interrupted
check "I·a_start_goes_with_the_execution_and_who_recorded_it" a_start_goes_with_the_execution_and_who_recorded_it
check "I·an_end_goes_with_a_finished_departure_after_its_start" an_end_goes_with_a_finished_departure_after_its_start
check "I·an_interruption_finishes_the_departure_with_its_cause" an_interruption_finishes_the_departure_with_its_cause
check "I·the_application_user_records_the_execution" the_application_user_records_the_execution
check "I·the_regularization_columns_exist_and_an_old_departure_has_none" the_regularization_columns_exist_and_an_old_departure_has_none
check "I·the_mark_needs_its_moment_and_only_marks_an_open_departure" the_mark_needs_its_moment_and_only_marks_an_open_departure
check "I·who_regularized_and_when_go_together_on_a_finished_departure" who_regularized_and_when_go_together_on_a_finished_departure
check "I·an_early_start_reason_is_of_a_regularization_and_up_to_500" an_early_start_reason_is_of_a_regularization_and_up_to_500
check "I·the_departures_past_their_end_are_found_through_a_partial_index" the_departures_past_their_end_are_found_through_a_partial_index
check "I·the_application_user_marks_and_regularizes" the_application_user_marks_and_regularizes
check "I·the_service_table_exists_with_one_row_per_reservation_of_a_departure" the_service_table_exists_with_one_row_per_reservation_of_a_departure
check "I·a_result_and_its_travelers_served_agree" a_result_and_its_travelers_served_agree
check "I·an_undelivered_service_has_its_cause_and_a_no_show_is_undelivered" an_undelivered_service_has_its_cause_and_a_no_show_is_undelivered
check "I·a_service_belongs_to_a_departure_of_its_tenant" a_service_belongs_to_a_departure_of_its_tenant
check "I·the_application_user_records_but_never_deletes_a_service" the_application_user_records_but_never_deletes_a_service
check "I·the_cost_table_keeps_many_lines_per_departure" the_cost_table_keeps_many_lines_per_departure
check "I·a_cost_needs_a_concept_and_an_amount_above_zero" a_cost_needs_a_concept_and_an_amount_above_zero
check "I·a_calculated_cost_is_the_unit_cost_times_the_travelers_and_a_manual_one_has_neither" a_calculated_cost_is_the_unit_cost_times_the_travelers_and_a_manual_one_has_neither
check "I·a_cost_without_a_catalogued_cost_is_manual_and_justified" a_cost_without_a_catalogued_cost_is_manual_and_justified
check "I·a_cost_belongs_to_a_departure_of_its_tenant" a_cost_belongs_to_a_departure_of_its_tenant
check "I·a_cost_key_is_unique_in_a_tenant_and_8_to_128_characters" a_cost_key_is_unique_in_a_tenant_and_8_to_128_characters
check "I·the_application_user_records_but_never_changes_a_cost" the_application_user_records_but_never_changes_a_cost
check "I·the_cancellation_table_exists_with_one_row_per_reservation_of_a_departure" the_cancellation_table_exists_with_one_row_per_reservation_of_a_departure
check "I·a_cancellation_has_its_bounded_justification" a_cancellation_has_its_bounded_justification
check "I·a_cancellation_belongs_to_a_departure_of_its_tenant" a_cancellation_belongs_to_a_departure_of_its_tenant
check "I·the_application_user_records_but_never_changes_a_cancellation" the_application_user_records_but_never_changes_a_cancellation
check "I·the_emergency_table_exists_with_one_row_per_reservation_of_a_departure" the_emergency_table_exists_with_one_row_per_reservation_of_a_departure
check "I·an_emergency_has_its_bounded_detail_and_at_least_one_traveler" an_emergency_has_its_bounded_detail_and_at_least_one_traveler
check "I·an_emergency_belongs_to_a_departure_of_its_tenant" an_emergency_belongs_to_a_departure_of_its_tenant
check "I·the_application_user_records_but_never_changes_an_emergency" the_application_user_records_but_never_changes_an_emergency
check "I·the_cancellation_columns_exist_and_an_old_departure_has_none" the_cancellation_columns_exist_and_an_old_departure_has_none
check "I·a_cancelled_departure_has_its_instant_and_cause_and_only_it" a_cancelled_departure_has_its_instant_and_cause_and_only_it
check "I·the_cause_and_the_reason_agree_and_the_reason_is_bounded" the_cause_and_the_reason_agree_and_the_reason_is_bounded
check "I·a_cancellation_is_never_rewritten" a_cancellation_is_never_rewritten
check "I·the_application_user_cancels_a_departure_and_never_deletes_one" the_application_user_cancels_a_departure_and_never_deletes_one
check "I·the_full_rollback_leaves_nothing_and_the_rebuild_is_identical" the_full_rollback_leaves_nothing_and_the_rebuild_is_identical

[ "$fail" = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit "$fail"
