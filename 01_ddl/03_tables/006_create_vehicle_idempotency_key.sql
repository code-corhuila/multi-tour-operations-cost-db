-- The key of a vehicle creation retried: it answers the vehicle that the first one made, written in the same transaction (norm 5.3.8).
-- Apart from idempotency_key, whose key points to a departure. The foreign key is in 04_alter, its index in 10_indexes.
CREATE TABLE operations_cost.vehicle_idempotency_key (
    scope           text        NOT NULL,
    idempotency_key text        NOT NULL,
    vehicle_id      uuid        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_vehicle_idempotency_key PRIMARY KEY (scope, idempotency_key),
    CONSTRAINT chk_vehicle_idempotency_key_scope CHECK (char_length(scope) BETWEEN 1 AND 100),
    CONSTRAINT chk_vehicle_idempotency_key_length CHECK (char_length(idempotency_key) BETWEEN 8 AND 128)
);
