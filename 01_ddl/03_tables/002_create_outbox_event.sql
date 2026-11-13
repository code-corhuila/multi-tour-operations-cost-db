-- The same shape as the outbox of multi-tour-security, which job 7 already reads (plan D-04), with one difference: every
-- departure belongs to a tenant, so tenant_id is mandatory here. Fields and statuses follow 06-data/modeling-conventions.md;
-- the statuses other than PENDING are PROPUESTO there (ADR-004 D4). No foreign key leaves the schema (Annex J.3.4).
CREATE TABLE operations_cost.outbox_event (
    outbox_event_id uuid        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       uuid        NOT NULL,
    event_type      text        NOT NULL,
    event_version   integer     NOT NULL DEFAULT 1,
    aggregate_id    uuid        NOT NULL,
    actor_id        uuid,
    reason          text,
    payload         jsonb       NOT NULL,
    correlation_id  text        NOT NULL,
    occurred_at     timestamptz NOT NULL DEFAULT now(),
    published_at    timestamptz,
    status          text        NOT NULL DEFAULT 'PENDING',
    attempts        integer     NOT NULL DEFAULT 0,
    last_error      text,
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_outbox_event PRIMARY KEY (outbox_event_id),
    CONSTRAINT chk_outbox_event_status CHECK (status IN ('PENDING', 'PUBLISHED', 'FAILED')),
    CONSTRAINT chk_outbox_event_event_type CHECK (char_length(event_type) BETWEEN 1 AND 100),
    CONSTRAINT chk_outbox_event_event_version CHECK (event_version >= 1),
    CONSTRAINT chk_outbox_event_attempts CHECK (attempts >= 0),
    CONSTRAINT chk_outbox_event_reason CHECK (reason IS NULL OR char_length(reason) <= 500),
    CONSTRAINT chk_outbox_event_last_error CHECK (last_error IS NULL OR char_length(last_error) <= 1000),
    CONSTRAINT chk_outbox_event_correlation_id CHECK (char_length(correlation_id) BETWEEN 1 AND 128)
);
