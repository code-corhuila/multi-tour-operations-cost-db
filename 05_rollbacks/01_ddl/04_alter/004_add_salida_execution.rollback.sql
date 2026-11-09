ALTER TABLE operations_cost.salida
    DROP CONSTRAINT IF EXISTS chk_salida_interruption,
    DROP CONSTRAINT IF EXISTS chk_salida_execution_end,
    DROP CONSTRAINT IF EXISTS chk_salida_execution_start,
    DROP COLUMN IF EXISTS pending_regularization,
    DROP COLUMN IF EXISTS interruption_cause,
    DROP COLUMN IF EXISTS interrupted,
    DROP COLUMN IF EXISTS finished_by,
    DROP COLUMN IF EXISTS actual_end_at,
    DROP COLUMN IF EXISTS started_by,
    DROP COLUMN IF EXISTS actual_start_at;
