-- The personal emergency of one reservation of a departure in execution (HU-OPS-008, spec 009). One row per reservation of a
-- departure: the refund is determined once and the record is never rewritten. The reservation lives in commercial_reservation, so only
-- its id is kept (Annex J, no cross-schema keys); that the travelers affected do not exceed those of the reservation is judged by the
-- api. The foreign key to the departure is in 04_alter (Annex A: tables carry no keys).
CREATE TABLE operations_cost.salida_personal_emergency (
    tenant_id           uuid        NOT NULL,
    salida_id           uuid        NOT NULL,
    reservation_id      uuid        NOT NULL,
    affected_travelers  integer     NOT NULL,
    detail              text        NOT NULL,
    recorded_by         uuid        NOT NULL,
    recorded_at         timestamptz NOT NULL,
    CONSTRAINT pk_salida_personal_emergency PRIMARY KEY (salida_id, reservation_id),
    CONSTRAINT chk_salida_personal_emergency_affected_travelers CHECK (affected_travelers >= 1),
    CONSTRAINT chk_salida_personal_emergency_detail CHECK (char_length(detail) BETWEEN 1 AND 1000)
);
