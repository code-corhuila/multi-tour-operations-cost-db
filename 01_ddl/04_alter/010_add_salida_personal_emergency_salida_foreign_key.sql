-- The tenant travels in the key, so an emergency cannot carry a tenant other than its departure's. RESTRICT: a departure never
-- disappears from under what was recorded in it. Its index is in 10_indexes (Annex A rule 4).
ALTER TABLE operations_cost.salida_personal_emergency
    ADD CONSTRAINT fk_salida_personal_emergency_salida FOREIGN KEY (tenant_id, salida_id)
        REFERENCES operations_cost.salida (tenant_id, salida_id) ON DELETE RESTRICT;
