-- The assignment of a vehicle to a departure (06-data, logical record salida_vehicle_assignments), without a surrogate id:
-- the pair identifies it (plan D-04). The foreign keys go in 04_alter.
CREATE TABLE operations_cost.salida_vehicle (
    tenant_id   uuid        NOT NULL,
    salida_id   uuid        NOT NULL,
    vehicle_id  uuid        NOT NULL,
    assigned_by uuid        NOT NULL,
    assigned_at timestamptz NOT NULL,
    CONSTRAINT pk_salida_vehicle PRIMARY KEY (salida_id, vehicle_id)
);
