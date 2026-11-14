-- The writer reads, adds and moves forward a session cutoff and records a processed event; it deletes neither (spec 010, plan D-03).
-- The default privileges of 001 already give these; they are written here so the intent does not depend on them. A processed event
-- is never rewritten, so the UPDATE the default privileges brought is taken back.
GRANT SELECT ON operations_cost.account_session_cutoff, operations_cost.processed_event TO operations_cost_reader;
GRANT SELECT, INSERT, UPDATE ON operations_cost.account_session_cutoff TO operations_cost_writer;
GRANT SELECT, INSERT ON operations_cost.processed_event TO operations_cost_writer;
REVOKE UPDATE ON operations_cost.processed_event FROM operations_cost_writer;
