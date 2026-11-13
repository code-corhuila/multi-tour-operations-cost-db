-- A vehicle of a tenant (06-data, logical record vehicles), as the spec 002 of this repository and its plan D-01 decide.
-- A name as the operator calls it and a capacity in seats. The name and the bound of 100 are the decision of the Project Lead
-- of 2026-11-08 (06-data leaves them undefined). A vehicle is never deleted: what was assigned keeps its history (AC-DB-02.3).
-- tenant_id belongs to another domain (identity-audit) and is stored as an identifier, never as a foreign key (Annex J.3.4).
CREATE TABLE operations_cost.vehicle (
    vehicle_id uuid        NOT NULL,
    tenant_id  uuid        NOT NULL,
    name       text        NOT NULL,
    capacity   integer     NOT NULL,
    created_by uuid        NOT NULL,
    created_at timestamptz NOT NULL,
    CONSTRAINT pk_vehicle PRIMARY KEY (vehicle_id),
    -- the assignment references the vehicle together with its tenant, so the engine refuses a vehicle of another tenant
    CONSTRAINT uq_vehicle_tenant_id_vehicle_id UNIQUE (tenant_id, vehicle_id),
    CONSTRAINT chk_vehicle_name CHECK (char_length(btrim(name)) BETWEEN 1 AND 60),
    CONSTRAINT chk_vehicle_capacity CHECK (capacity BETWEEN 1 AND 100)
);
