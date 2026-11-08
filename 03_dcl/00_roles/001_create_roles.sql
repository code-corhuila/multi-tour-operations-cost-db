-- The roles carry permissions and cannot log in; the user operations_cost_app is created by the infrastructure
-- from a secret (Annex J.4) and joins operations_cost_writer in the next changeset.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operations_cost_reader') THEN
        CREATE ROLE operations_cost_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operations_cost_writer') THEN
        CREATE ROLE operations_cost_writer NOLOGIN;
    END IF;
END
$$;
