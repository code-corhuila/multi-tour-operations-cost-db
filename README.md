# multi-tour-operations-cost-db

The database of the operations-cost domain of **Multitour**: the schema `operations_cost` inside the single PostgreSQL
instance of the platform, built and reverted with Liquibase (course norm §5.2, Annexes A and J). This repository holds
the migrations and nothing else: the instance, its volume, its extensions and the user `operations_cost_app` belong to
`multi-tour-infra-postgres`. Documentation lives in `multi-tour-docs` (spec 001 of this repository,
`07-api/specs/operations-cost/multi-tour-operations-cost-db/`).

## What it holds

The schema `operations_cost`, the roles `operations_cost_reader` and `operations_cost_writer` (they cannot log in and have no
password) and the grant of the writer to `operations_cost_app`. The writer reads, inserts and updates and **never deletes**, with one exception, the assignment of a vehicle to a departure (HU-OPS-002 part B), and it never updates the four tables of records that are not rewritten, `salida_cost`, `salida_extraordinary_cancellation`, `salida_personal_emergency` and `processed_event`:
a departure is cancelled, never erased. The tables, of HU-OPS-001 to HU-OPS-008 and HU-SEC-005:

- `salida`: the departures of a tour, with their code `SAL-nnn` per tenant, the scheduled start and estimated end, the time
  zone and the status;
- `outbox_event`: the events written in the same transaction as the change, which job 7 reads and delivers;
- `idempotency_key`: the key of a creation and the departure it created, so a repeat answers the same departure;
- `vehicle`: the vehicles of the tenant, with a name that is unique per tenant ignoring case and a capacity from 1 to 100;
- `salida_vehicle`: the vehicles assigned to a departure;
- `vehicle_idempotency_key`: the key of the registration of a vehicle and the vehicle it created;
- `salida_service`: what each reservation of a departure received (delivered or not, travelers served, cause, no-show), one row per reservation, replaced when saved again;
- `salida_cost`: the real operational costs of a departure, one row per line, calculated (catalogued cost times the travelers served) or a real expense with its justification when the tour has no parametrized cost; never updated nor deleted.
- `salida_extraordinary_cancellation`: the extraordinary cancellation of a reservation of a departure in execution, one row per reservation, with its justification, who and when; inserted and read, never updated nor deleted.
- `salida_personal_emergency`: the personal emergency of a reservation of a departure in execution (HU-OPS-008), one row per reservation, with the travelers affected (at least one), its detail (1 to 1000 characters), who and when; inserted and read, never updated nor deleted. That the travelers do not exceed those of the reservation is judged by the api, because the reservation lives in another schema.
- `account_session_cutoff`: the session cutoff of an account (HU-SEC-005), one row per account with its tenant when it has one; the api refuses the tokens issued before `revoked_from`. Inserted, read and moved forward, never deleted.
- `processed_event`: the id of each event of the relay already applied, so a repeat changes nothing; inserted and read, never updated nor deleted.

The table `salida` also keeps what happened in a departure (HU-OPS-003): the real start and end, who recorded each, whether it ended as an interruption and why, the mark of pending regularization with the moment it was set (`pending_marked_at`, which stays after the mark is cleared as the anchor of the retention count), and, when a person regularized it, who and when (`regularized_by`, `regularized_at`) and why it started earlier than scheduled (`early_start_reason`). The engine checks that they agree with the state; a partial index, `idx_salida_open_past_end`, finds the open departures that job 3 has not marked yet. It also keeps the cancellation of a departure (HU-OPS-006): when it was cancelled, by whom when a person did, the cause (not attributable to the customer, or not performed) and, for a departure regularized as not performed, the written reason; the engine ties them to the state `CANCELLED` and a trigger refuses to change them once written.

## How it runs

The runner is the only thing in `deploy/`: Liquibase 5.0.4 with the PostgreSQL driver and the migrations copied inside its
image. It has its own control tables, `databasechangelog_operations_cost` and `databasechangeloglock_operations_cost`, so
two domains can migrate the same instance. It is started from the root composition of `multi-tour-infra-postgres`:

```sh
docker compose --profile tooling run --rm operations-cost-db-migrate
```

The runner reads `PG_DATABASE`, `PG_ADMIN_USER` and `PG_ADMIN_PASSWORD` from the environment file of the infrastructure.
`.env.example` names them; a real `.env` is never versioned.

## Where the data is

In the schema `operations_cost` of the instance defined by `multi-tour-infra-postgres`. Nothing of this domain lives in
`public` except the two control tables of the runner. A reference to another domain (the tenant, the tour of the catalog)
is a stored identifier with no foreign key.

## How it is tested

```sh
bash tests/db-ci.sh          # needs Docker only
bash tests/check-structure.sh
```

`tests/db-ci.sh` starts a throwaway PostgreSQL and the runner on a private network, with passwords generated on the spot, and
checks that the schema builds from empty and nothing of the domain lives in `public`, that a second run applies zero
changesets, that the full rollback leaves nothing and the rebuild is identical, that the repository has its own control table
and defines no database service, volume or extension, and that `operations_cost_app` writes only in its own schema. The same
file is what `db-ci.yml` runs on every pull request toward `develop` and `qa`; while GitHub Actions is locked for billing the
pull request pastes the local run instead. `tests/check-structure.sh` is the static check of `ci.yml`.

## What is missing

What the other stories of the domain will need: whatever the ordinary novelties and the history of a departure keep (another story).

## Branching

Three permanent branches, `develop`, `qa` and `main`; none accepts a direct commit. A task enters `develop` through a
`feat/`, `fix/` or `chore/` branch and a pull request; `qa` through `qa/` and `main` through `release/` or `hotfix/`,
always by re-applying commits with `git cherry-pick -x`, never by merging one permanent branch into another. A commit is
`<type>(<scope>): <description>` in lower case, and a pull request cites its story as `code-corhuila/multi-tour-docs#NN`.
