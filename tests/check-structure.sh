#!/usr/bin/env bash
# Static checks of the repository, with no Docker (Annex A, norm 5.1, Annex I, Annex J). The four steps of Annex A that need a
# database are in tests/db-ci.sh. A secret in a repository that is public is a grave fault: here the names of the files that
# hold one are refused and no password is written in a migration.
set -u
cd "$(dirname "$0")/.."

fail=0
bad() { echo "FAIL: $1"; fail=1; }

# ---- 1. every family and subfolder of Annex A carries its changelog.yaml, included in order
declare -A subs=(
  [01_ddl]="00_extensions 01_schemas 02_types 03_tables 04_alter 05_views 06_materialized_views 07_functions 08_procedures 09_triggers 10_indexes"
  [02_dml]="00_inserts 01_updates 02_deletes 03_upserts 04_patches"
  [03_dcl]="00_roles 01_grants 02_policies"
  [04_tcl]="00_transaction_blocks 01_manual_recoveries 02_release_tags"
)
for family in 01_ddl 02_dml 03_dcl 04_tcl; do
  [ -f "$family/changelog.yaml" ] || bad "$family/changelog.yaml is missing"
  previous=0
  for sub in ${subs[$family]}; do
    [ -f "$family/$sub/changelog.yaml" ] || bad "$family/$sub/changelog.yaml is missing"
    line=$(grep -n "$sub/changelog.yaml" "$family/changelog.yaml" 2>/dev/null | head -1 | cut -d: -f1)
    [ -n "$line" ] || { bad "$family/changelog.yaml does not include $sub"; continue; }
    [ "$line" -gt "$previous" ] || bad "$family/changelog.yaml includes $sub out of order"
    previous=$line
  done
done

# ---- 2. the master changelog includes the four families in order
master=changelog/changelog-master.yaml
[ -f "$master" ] || bad "$master is missing"
previous=0
for family in 01_ddl 02_dml 03_dcl 04_tcl; do
  line=$(grep -n "$family/changelog.yaml" "$master" 2>/dev/null | head -1 | cut -d: -f1)
  [ -n "$line" ] || { bad "$master does not include $family"; continue; }
  [ "$line" -gt "$previous" ] || bad "$master includes $family out of order"
  previous=$line
done

# ---- 3. every changeset has its rollback and a unique id, and the file it names exists (norm 5.2.3)
for file in $(find 01_ddl 02_dml 03_dcl 04_tcl -name changelog.yaml); do
  dir=$(dirname "$file")
  [ "$(grep -c 'changeSet:' "$file")" = "$(grep -c 'rollback:' "$file")" ] || bad "$file has a changeset without a rollback"
  for rollback in $(grep -oE '[^ ]+\.rollback\.sql' "$file"); do
    [ -f "$dir/$rollback" ] || bad "$file points to $rollback, which does not exist"
  done
done
duplicated=$(grep -rhE '^\s+id:' 01_ddl 02_dml 03_dcl 04_tcl | sort | uniq -d)
[ -z "$duplicated" ] || bad "a changeset id is used twice: $duplicated"
sql_without_comments() { find "$@" -type f \( -name '*.sql' -o -name '*.yaml' -o -name '*.yml' -o -name Dockerfile \) -print0 | xargs -0 -r sed 's/--.*$//; s/^[[:space:]]*#.*$//; /^[[:space:]]*comment:/d'; }

# ---- 4. the migrations define no extension, no login and no secret; the user of the domain is the infrastructure's (J.4, J.7)
sql_without_comments 01_ddl 02_dml 03_dcl 04_tcl 05_rollbacks deploy | grep -qiE 'create[[:space:]]+extension' && bad "an extension is created: it belongs to the instance (Annex J.4)"
sql_without_comments 01_ddl 02_dml 03_dcl 04_tcl 05_rollbacks | grep -qiE '(^|[^a-z_])login([^a-z_]|$)|password' && bad "a LOGIN role or a password appears in the migrations (Annex A rule 10)"
sql_without_comments 01_ddl 02_dml 03_dcl 04_tcl 05_rollbacks | grep -qiE 'create[[:space:]]+(role|user)[[:space:]]+operations_cost_app' && bad "operations_cost_app is created here: the infrastructure creates it (Annex J.7)"

# ---- 5. deploy/compose.yml holds only the runner: no database image and no volume (J.7)
body="$(sed 's/^[[:space:]]*#.*$//' deploy/compose.yml 2>/dev/null)"
[ -n "$body" ] || bad "deploy/compose.yml is missing"
echo "$body" | grep -qE '^[[:space:]]*image:[[:space:]]*["'"'"']?postgres' && bad "deploy/compose.yml defines a PostgreSQL image"
echo "$body" | grep -qE '^[[:space:]]*volumes:' && bad "deploy/compose.yml declares volumes"
echo "$body" | grep -q 'operations-cost-db-migrate' || bad "deploy/compose.yml does not declare operations-cost-db-migrate"

# ---- 6. no secret and no real environment file is versioned (norm 5.1, J.5.1)
[ -z "$(git ls-files | grep -E '(^|/)\.env$|\.pem$')" ] || bad "an .env or a key is versioned"
[ -f .env.example ] || bad ".env.example is missing"
grep -qE '^\.env$' .gitignore 2>/dev/null || bad ".gitignore does not ignore .env"

# ---- 7. the workflows follow the course rules: pull requests only, no schedule, bounded, one run per branch (ADR-004 D7)
for wf in .github/workflows/ci.yml .github/workflows/db-ci.yml; do
  [ -f "$wf" ] || { bad "$wf is missing"; continue; }
  grep -qE '^\s*(schedule|push|workflow_dispatch):' "$wf" && bad "$wf runs on more than pull requests: the course forbids a schedule, a push and a manual trigger"
  grep -q 'branches: \[develop, qa\]' "$wf" || bad "$wf does not run on pull requests toward develop and qa only"
  grep -q 'contents: read' "$wf" || bad "$wf does not limit its token to contents: read"
  grep -q 'timeout-minutes: 10' "$wf" || bad "$wf does not set timeout-minutes: 10"
  grep -q 'cancel-in-progress: true' "$wf" || bad "$wf does not cancel a run in progress"
done
[ -f .github/CODEOWNERS ] || bad ".github/CODEOWNERS is missing"

[ "$fail" = 0 ] && echo "STRUCTURE OK" || echo "STRUCTURE FAILED"
exit "$fail"
