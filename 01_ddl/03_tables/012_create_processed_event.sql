-- The events already applied (HU-SEC-005, spec 010): the relay may deliver the same event twice (Annex D), and a repeat changes nothing.
CREATE TABLE operations_cost.processed_event (
    event_id      uuid        NOT NULL,
    processed_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_processed_event PRIMARY KEY (event_id)
);
