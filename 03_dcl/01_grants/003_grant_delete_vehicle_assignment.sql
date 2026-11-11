-- Taking a vehicle off a departure deletes its assignment row (api spec 008, HU-OPS-002 part B). The writer inserted and updated;
-- it now deletes this one table and nothing else: a cost, a service record and a departure are never deleted.
GRANT DELETE ON operations_cost.salida_vehicle TO operations_cost_writer;
