-- What each reservation of a departure received (HU-OPS-004, spec 005). The reservation lives in commercial_reservation, so it is
-- kept as its id only, with no key (Annex J); the keys to the departure are in 04_alter. A row is replaced when it is saved again.
-- The travelers reserved are not copied here: whether a partial delivery has its cause is judged by the service, which can read them.
CREATE TABLE operations_cost.salida_service (
    tenant_id        uuid        NOT NULL,
    salida_id        uuid        NOT NULL,
    reservation_id   uuid        NOT NULL,
    result           text        NOT NULL,
    travelers_served integer     NOT NULL,
    cause            text,
    no_show          boolean     NOT NULL DEFAULT false,
    recorded_by      uuid        NOT NULL,
    recorded_at      timestamptz NOT NULL,
    CONSTRAINT pk_salida_service PRIMARY KEY (salida_id, reservation_id),
    CONSTRAINT chk_salida_service_result CHECK (result IN ('DELIVERED', 'NOT_DELIVERED')),
    -- delivered means at least one traveler was served; not delivered means none
    CONSTRAINT chk_salida_service_travelers CHECK (
        (result = 'DELIVERED' AND travelers_served >= 1) OR (result = 'NOT_DELIVERED' AND travelers_served = 0)),
    -- an undelivered service always has its cause; any cause has 1 to 500 characters
    CONSTRAINT chk_salida_service_cause CHECK (
        (result <> 'NOT_DELIVERED' OR cause IS NOT NULL) AND (cause IS NULL OR char_length(cause) BETWEEN 1 AND 500)),
    -- a no-show without notice is an undelivered service that stays charged
    CONSTRAINT chk_salida_service_no_show CHECK (NOT no_show OR result = 'NOT_DELIVERED')
);
