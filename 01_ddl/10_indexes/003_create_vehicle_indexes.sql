-- The unique name per tenant ignoring case and the spaces around it (RN-OPS-DB-21), and the lookup of the departures of a vehicle
-- that the overlap check of the service makes (plan D-05). Both tables are new and empty, so they are not created concurrently.
CREATE UNIQUE INDEX uq_vehicle_tenant_id_name ON operations_cost.vehicle (tenant_id, lower(btrim(name)));
CREATE INDEX idx_salida_vehicle_tenant_id_vehicle_id ON operations_cost.salida_vehicle (tenant_id, vehicle_id);
-- the foreign key to the departure has its own index over the same pair, so a delete of a departure never scans the assignments
CREATE INDEX idx_salida_vehicle_tenant_id_salida_id ON operations_cost.salida_vehicle (tenant_id, salida_id);
