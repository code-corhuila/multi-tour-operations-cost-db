-- What happened in a departure (HU-OPS-003, spec 003): the real start and end, who recorded each, whether it ended as an
-- interruption and why, and the mark of pending regularization that job 3 will set. The columns that only make sense once the
-- departure runs are nullable; the two booleans have a constant default so the rows that already exist stay valid (plan D-02).
-- The checks give the engine the coherence the domain also checks; the start is NOT compared with the schedule here, because a
-- regularization may start earlier with its reason (plan D-04).
ALTER TABLE operations_cost.salida
    ADD COLUMN actual_start_at         timestamptz,
    ADD COLUMN started_by              uuid,
    ADD COLUMN actual_end_at           timestamptz,
    ADD COLUMN finished_by             uuid,
    ADD COLUMN interrupted             boolean NOT NULL DEFAULT false,
    ADD COLUMN interruption_cause      text,
    ADD COLUMN pending_regularization  boolean NOT NULL DEFAULT false,
    -- running or finished departures have a start and who recorded it; scheduled and cancelled ones have none
    ADD CONSTRAINT chk_salida_execution_start CHECK (
        (status IN ('IN_EXECUTION', 'FINISHED')) = (actual_start_at IS NOT NULL AND started_by IS NOT NULL)
        AND (actual_start_at IS NULL) = (started_by IS NULL)),
    -- a finished departure has an end and who recorded it, never before its start; any other state has none
    ADD CONSTRAINT chk_salida_execution_end CHECK (
        (status = 'FINISHED') = (actual_end_at IS NOT NULL AND finished_by IS NOT NULL)
        AND (actual_end_at IS NULL) = (finished_by IS NULL)
        AND (actual_end_at IS NULL OR actual_end_at >= actual_start_at)),
    -- an interruption ends the departure FINISHED (PDR K1) and always has its cause of 1 to 1000 characters
    ADD CONSTRAINT chk_salida_interruption CHECK (
        (NOT interrupted OR status = 'FINISHED')
        AND (interrupted = (interruption_cause IS NOT NULL))
        AND (interruption_cause IS NULL OR char_length(interruption_cause) BETWEEN 1 AND 1000));
