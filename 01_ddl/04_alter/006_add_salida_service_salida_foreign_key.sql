-- The tenant travels in the key, so a record cannot carry a tenant other than its departure's (AC-DB-05.4). RESTRICT: a departure
-- never disappears from under what was recorded for it. Its index is in 10_indexes (Annex A rule 4).
ALTER TABLE operations_cost.salida_service
    ADD CONSTRAINT fk_salida_service_salida FOREIGN KEY (tenant_id, salida_id)
        REFERENCES operations_cost.salida (tenant_id, salida_id) ON DELETE RESTRICT;
