-- The extraordinary cancellation of one reservation of a departure in execution (HU-OPS-005, spec 007). One row per reservation of a
-- departure: it happens once and is never rewritten. The reservation lives in commercial_reservation, so only its id is kept (Annex J, no
-- cross-schema keys). The foreign key to the departure is in 04_alter (Annex A: tables carry no keys).
CREATE TABLE operations_cost.salida_extraordinary_cancellation (
    tenant_id       uuid        NOT NULL,
    salida_id       uuid        NOT NULL,
    reservation_id  uuid        NOT NULL,
    justification   text        NOT NULL,
    recorded_by     uuid        NOT NULL,
    recorded_at     timestamptz NOT NULL,
    CONSTRAINT pk_salida_extraordinary_cancellation PRIMARY KEY (salida_id, reservation_id),
    CONSTRAINT chk_salida_extraordinary_cancellation_justification CHECK (char_length(justification) BETWEEN 1 AND 500)
);
