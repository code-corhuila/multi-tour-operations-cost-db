REVOKE operations_cost_writer FROM operations_cost_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_cost REVOKE SELECT, INSERT, UPDATE ON TABLES FROM operations_cost_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA operations_cost REVOKE SELECT ON TABLES FROM operations_cost_reader;
REVOKE ALL ON ALL TABLES IN SCHEMA operations_cost FROM operations_cost_reader, operations_cost_writer;
REVOKE ALL ON SCHEMA operations_cost FROM operations_cost_reader, operations_cost_writer;
