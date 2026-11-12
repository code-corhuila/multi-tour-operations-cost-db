-- Runs the function that refuses a change of a cancellation already written (HU-OPS-006, spec 008 D-05).
CREATE TRIGGER trg_salida_cancellation_is_final
    BEFORE UPDATE ON operations_cost.salida
    FOR EACH ROW EXECUTE FUNCTION operations_cost.salida_cancellation_is_final();
