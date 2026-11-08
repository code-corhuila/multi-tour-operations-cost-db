GRANT USAGE ON SCHEMA operations_cost TO operations_cost_reader, operations_cost_writer;
GRANT SELECT ON ALL TABLES IN SCHEMA operations_cost TO operations_cost_reader;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA operations_cost TO operations_cost_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_cost GRANT SELECT ON TABLES TO operations_cost_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_cost GRANT SELECT, INSERT, UPDATE ON TABLES TO operations_cost_writer;
-- the user the service connects with (created by multi-tour-infra-postgres) reaches the schema only through this role
GRANT operations_cost_writer TO operations_cost_app;
