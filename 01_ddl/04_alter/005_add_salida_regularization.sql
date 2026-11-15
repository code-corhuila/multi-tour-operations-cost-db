-- What happens to a departure that nobody started or closed (HU-OPS-003 part B, spec 004): the moment job 3 marked it, who
-- regularized it and when, and why it started earlier than scheduled. The moment of the mark stays after the departure is
-- regularized or finished: it is the anchor of the retention count (PDR Q1), while pending_regularization says whether it is pending now.
-- The start is NOT compared with the schedule here: the domain allows an early start only in a regularization (plan D-05).
ALTER TABLE operations_cost.salida
    ADD COLUMN pending_marked_at  timestamptz,
    ADD COLUMN regularized_by     uuid,
    ADD COLUMN regularized_at     timestamptz,
    ADD COLUMN early_start_reason text,
    -- the mark is pending only on a departure that is still open, and always has its moment
    ADD CONSTRAINT chk_salida_pending_mark CHECK (
        NOT pending_regularization
        OR (pending_marked_at IS NOT NULL AND status IN ('SCHEDULED', 'IN_EXECUTION'))),
    -- who regularized and when go together, and only on a finished departure
    ADD CONSTRAINT chk_salida_regularization CHECK (
        (regularized_by IS NULL) = (regularized_at IS NULL)
        AND (regularized_by IS NULL OR status = 'FINISHED')),
    -- the reason of an early start belongs to a regularization and is 1 to 500 characters
    ADD CONSTRAINT chk_salida_early_start_reason CHECK (
        early_start_reason IS NULL
        OR (regularized_by IS NOT NULL AND char_length(early_start_reason) BETWEEN 1 AND 500));
