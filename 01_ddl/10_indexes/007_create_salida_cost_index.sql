-- The key to the departure has its own index over the pair, so the costs of a departure are found without scanning the others.
-- The table is new and empty, so it is not created concurrently.
CREATE INDEX idx_salida_cost_tenant_id_salida_id ON operations_cost.salida_cost (tenant_id, salida_id);
