-- The tenant travels in the key, so a cancellation cannot carry a tenant other than its departure's. RESTRICT: a departure never
-- disappears from under what was cancelled in it. Its index is in 10_indexes (Annex A rule 4).
ALTER TABLE operations_cost.salida_extraordinary_cancellation
    ADD CONSTRAINT fk_salida_extraordinary_cancellation_salida FOREIGN KEY (tenant_id, salida_id)
        REFERENCES operations_cost.salida (tenant_id, salida_id) ON DELETE RESTRICT;
