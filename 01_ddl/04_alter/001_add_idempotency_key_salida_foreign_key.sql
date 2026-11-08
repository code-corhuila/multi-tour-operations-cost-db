-- Both tables are of this domain, so the key is a real foreign key. Its index is in 10_indexes (Annex A rule 4).
ALTER TABLE operations_cost.idempotency_key
    ADD CONSTRAINT fk_idempotency_key_salida FOREIGN KEY (salida_id) REFERENCES operations_cost.salida (salida_id) ON DELETE RESTRICT;
