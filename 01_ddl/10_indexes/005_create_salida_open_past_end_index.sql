-- Job 3 asks every 15 minutes for the open departures not yet marked, oldest estimated end first; the subset shrinks as they close.
-- Created CONCURRENTLY because the table has rows (norm 7), in its own change set outside a transaction.
CREATE INDEX CONCURRENTLY idx_salida_open_past_end ON operations_cost.salida (estimated_end_at)
    WHERE status IN ('SCHEDULED', 'IN_EXECUTION') AND NOT pending_regularization;
