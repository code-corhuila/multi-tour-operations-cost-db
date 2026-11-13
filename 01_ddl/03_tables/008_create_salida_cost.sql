-- A real operational cost of a departure (HU-OPS-007, spec 006). One row per cost line: calculated from the catalogued cost of the tour and
-- the travelers actually served, or typed as the real expense that was paid. The total of a departure is the sum of its lines and is never
-- stored; the status of a cost is not stored either (the PDR does not enumerate it). The key of the creation is a column of the line, so
-- a line and its key are one row. The foreign key to the departure is in 04_alter (Annex A: tables carry no keys).
CREATE TABLE operations_cost.salida_cost (
    cost_id                  uuid        NOT NULL,
    tenant_id                uuid        NOT NULL,
    salida_id                uuid        NOT NULL,
    concept                  text        NOT NULL,
    amount_cents             bigint      NOT NULL,
    mode                     text        NOT NULL,
    unit_cost_cents          bigint,
    travelers_served         integer,
    without_parametrization  boolean     NOT NULL DEFAULT false,
    justification            text,
    idempotency_key          text        NOT NULL,
    recorded_by              uuid        NOT NULL,
    recorded_at              timestamptz NOT NULL,
    CONSTRAINT pk_salida_cost PRIMARY KEY (cost_id),
    CONSTRAINT uq_salida_cost_tenant_key UNIQUE (tenant_id, idempotency_key),
    CONSTRAINT chk_salida_cost_concept CHECK (char_length(concept) BETWEEN 1 AND 200),
    CONSTRAINT chk_salida_cost_amount CHECK (amount_cents > 0),
    CONSTRAINT chk_salida_cost_key_length CHECK (char_length(idempotency_key) BETWEEN 8 AND 128),
    -- calculated: the catalogued cost times the travelers served, both kept; manual: neither
    CONSTRAINT chk_salida_cost_calculation CHECK (
        (mode = 'CALCULATED' AND unit_cost_cents IS NOT NULL AND travelers_served IS NOT NULL AND travelers_served >= 1 AND amount_cents = unit_cost_cents * travelers_served)
        OR (mode = 'MANUAL' AND unit_cost_cents IS NULL AND travelers_served IS NULL)),
    -- a cost taken without a catalogued cost is a manual one with its written justification of 1 to 500 characters, and only such a cost has one
    CONSTRAINT chk_salida_cost_justification CHECK (
        (without_parametrization = (justification IS NOT NULL))
        AND (NOT without_parametrization OR mode = 'MANUAL')
        AND (justification IS NULL OR char_length(justification) BETWEEN 1 AND 500))
);
