-- A cost is never rewritten: a mistake is answered with another line (spec 006, plan D-07). The writer inserts and reads, nothing more.
-- This runs after the grants of 001 on every database, so the grant of UPDATE on all tables does not bring it back.
REVOKE UPDATE ON operations_cost.salida_cost FROM operations_cost_writer;
