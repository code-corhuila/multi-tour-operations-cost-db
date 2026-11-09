-- The tenant travels in the key, so a cost cannot carry a tenant other than its departure's. RESTRICT: a departure never disappears from
-- under what it cost. Its index is in 10_indexes (Annex A rule 4).
ALTER TABLE operations_cost.salida_cost
    ADD CONSTRAINT fk_salida_cost_salida FOREIGN KEY (tenant_id, salida_id)
        REFERENCES operations_cost.salida (tenant_id, salida_id) ON DELETE RESTRICT;
