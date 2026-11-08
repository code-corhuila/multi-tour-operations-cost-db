-- A key belongs to the vehicle it created and that vehicle cannot disappear from under it (RESTRICT). Its index is in 10_indexes.
ALTER TABLE operations_cost.vehicle_idempotency_key
    ADD CONSTRAINT fk_vehicle_idempotency_key_vehicle FOREIGN KEY (vehicle_id) REFERENCES operations_cost.vehicle (vehicle_id) ON DELETE RESTRICT;
