-- A creation retried with the same key answers the departure that the first one made. The key is written in the same transaction
-- as that departure (norm 5.3.8). Its foreign key to the departure is in 04_alter (Annex A: tables carry no keys).
CREATE TABLE operations_cost.idempotency_key (
    scope           text        NOT NULL,
    idempotency_key text        NOT NULL,
    salida_id       uuid        NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_idempotency_key PRIMARY KEY (scope, idempotency_key),
    CONSTRAINT chk_idempotency_key_scope CHECK (char_length(scope) BETWEEN 1 AND 100),
    CONSTRAINT chk_idempotency_key_length CHECK (char_length(idempotency_key) BETWEEN 8 AND 128)
);
