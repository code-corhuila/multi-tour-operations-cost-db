ALTER TABLE operations_cost.salida_vehicle
    DROP CONSTRAINT IF EXISTS fk_salida_vehicle_vehicle,
    DROP CONSTRAINT IF EXISTS fk_salida_vehicle_salida;
ALTER TABLE operations_cost.salida DROP CONSTRAINT IF EXISTS uq_salida_tenant_id_salida_id;
