-- An emergency is a trace and is never rewritten (spec 009, plan D-06). The writer inserts and reads, nothing more.
-- This runs after the grants of 001 on every database, so the grant of UPDATE on all tables does not bring it back.
REVOKE UPDATE ON operations_cost.salida_personal_emergency FROM operations_cost_writer;
