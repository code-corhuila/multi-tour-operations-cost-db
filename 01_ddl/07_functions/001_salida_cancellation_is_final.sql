-- A cancellation is never rewritten (HU-OPS-006, spec 008 D-05): the instant was already sent to another domain, and the engine is the
-- last guard. The row of a departure that is not cancelled is not touched by this function. The refusal is a check violation (23514),
-- the code of the other rules of this table, so the service can tell it apart from any other exception that a function raises.
CREATE FUNCTION operations_cost.salida_cancellation_is_final() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status = 'CANCELLED'
       AND (NEW.cancelled_at IS DISTINCT FROM OLD.cancelled_at
            OR NEW.cancelled_by IS DISTINCT FROM OLD.cancelled_by
            OR NEW.cancellation_cause IS DISTINCT FROM OLD.cancellation_cause
            OR NEW.cancellation_reason IS DISTINCT FROM OLD.cancellation_reason) THEN
        RAISE EXCEPTION 'a cancellation is final' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;
