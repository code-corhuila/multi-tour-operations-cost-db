-- The cancellation of a departure (HU-OPS-006, spec 008): the instant, who cancelled it when a person did, the cause and, for a
-- departure regularized as not performed, the written reason. A departure is cancelled once and for good (CA-029), so the instant is
-- the one every later request answers. The account lives in the schema security: only its id is kept, with no key.
ALTER TABLE operations_cost.salida
    ADD COLUMN cancelled_at         timestamptz,
    ADD COLUMN cancelled_by         uuid,
    ADD COLUMN cancellation_cause   text,
    ADD COLUMN cancellation_reason  text,
    -- a cancelled departure has its instant and its cause; no other has any of the four
    ADD CONSTRAINT chk_salida_cancellation CHECK (
        (status = 'CANCELLED') = (cancelled_at IS NOT NULL AND cancellation_cause IS NOT NULL)
        AND (cancelled_at IS NULL) = (cancellation_cause IS NULL)
        AND (status = 'CANCELLED' OR (cancelled_by IS NULL AND cancellation_reason IS NULL))),
    ADD CONSTRAINT chk_salida_cancellation_cause CHECK (
        cancellation_cause IS NULL OR cancellation_cause IN ('NOT_ATTRIBUTABLE_TO_CUSTOMER', 'NOT_CARRIED_OUT')),
    -- the written reason belongs to a departure that did not take place, and is 1 to 500 characters
    ADD CONSTRAINT chk_salida_cancellation_reason CHECK (
        (cancellation_cause IS NOT DISTINCT FROM 'NOT_CARRIED_OUT') = (cancellation_reason IS NOT NULL)
        AND (cancellation_reason IS NULL OR char_length(cancellation_reason) BETWEEN 1 AND 500));
