ALTER TABLE operations_cost.salida
    DROP CONSTRAINT IF EXISTS chk_salida_early_start_reason,
    DROP CONSTRAINT IF EXISTS chk_salida_regularization,
    DROP CONSTRAINT IF EXISTS chk_salida_pending_mark,
    DROP COLUMN IF EXISTS early_start_reason,
    DROP COLUMN IF EXISTS regularized_at,
    DROP COLUMN IF EXISTS regularized_by,
    DROP COLUMN IF EXISTS pending_marked_at;
