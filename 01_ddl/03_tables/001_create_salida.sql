-- A departure (06-data, logical record salidas), as the spec 001 of this repository and its plan D-03 decide.
-- No column has a default: the service states every value, so a retry keeps the same id and nothing is decided by the engine
-- in the dark. tenant_id and service_id belong to other domains (identity-audit, commercial-reservation): they are stored
-- as identifiers and are never foreign keys (Annex J.3.4). The capacity is not here: commercial-reservation owns it (ADR-004 D4).
CREATE TABLE operations_cost.salida (
    salida_id        uuid        NOT NULL,
    tenant_id        uuid        NOT NULL,
    code             text        NOT NULL,
    service_id       uuid        NOT NULL,
    starts_at        timestamptz NOT NULL,
    estimated_end_at timestamptz NOT NULL,
    time_zone        text        NOT NULL,
    status           text        NOT NULL,
    scheduled_by     uuid        NOT NULL,
    scheduled_at     timestamptz NOT NULL,
    CONSTRAINT pk_salida PRIMARY KEY (salida_id),
    -- the code the contract gives a departure, unique inside a tenant (a tour can be sold by two tenants)
    CONSTRAINT uq_salida_tenant_id_code UNIQUE (tenant_id, code),
    CONSTRAINT chk_salida_code CHECK (code ~ '^SAL-[0-9]{3,6}$'),
    -- a tour can last several days, so the end may fall on any later day, but never before the start
    CONSTRAINT chk_salida_estimated_end_at CHECK (estimated_end_at >= starts_at),
    CONSTRAINT chk_salida_time_zone CHECK (char_length(time_zone) BETWEEN 1 AND 64),
    -- the four states of the PDR (section 16, decision H3), with the codes of the contract
    CONSTRAINT chk_salida_status CHECK (status IN ('SCHEDULED', 'IN_EXECUTION', 'FINISHED', 'CANCELLED'))
);
