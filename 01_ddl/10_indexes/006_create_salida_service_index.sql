-- The key to the departure has its own index over the pair, so the reading of a departure never scans the records of the others.
-- The table is new and empty, so it is not created concurrently.
CREATE INDEX idx_salida_service_tenant_id_salida_id ON operations_cost.salida_service (tenant_id, salida_id);
