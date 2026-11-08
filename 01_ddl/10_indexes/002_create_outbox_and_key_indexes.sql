CREATE INDEX idx_outbox_event_status_next_attempt_at ON operations_cost.outbox_event (status, next_attempt_at);
-- Serves the foreign key of the key table (the primary key already serves the lookup by scope and key)
CREATE INDEX idx_idempotency_key_salida_id ON operations_cost.idempotency_key (salida_id);
