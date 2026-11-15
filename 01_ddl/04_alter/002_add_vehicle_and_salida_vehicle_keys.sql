-- The tenant travels in both keys, so an assignment cannot join a vehicle and a departure of different tenants (RN-OPS-DB-23).
-- RESTRICT: neither a departure nor a vehicle disappears from under an assignment. The unique key of the departure over the tenant
-- is backed by its primary key, so it cannot fail on rows that already exist.
ALTER TABLE operations_cost.salida
    ADD CONSTRAINT uq_salida_tenant_id_salida_id UNIQUE (tenant_id, salida_id);
ALTER TABLE operations_cost.salida_vehicle
    ADD CONSTRAINT fk_salida_vehicle_salida FOREIGN KEY (tenant_id, salida_id)
        REFERENCES operations_cost.salida (tenant_id, salida_id) ON DELETE RESTRICT,
    ADD CONSTRAINT fk_salida_vehicle_vehicle FOREIGN KEY (tenant_id, vehicle_id)
        REFERENCES operations_cost.vehicle (tenant_id, vehicle_id) ON DELETE RESTRICT;
