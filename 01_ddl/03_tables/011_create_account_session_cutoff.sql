-- The session cutoff of an account (HU-SEC-005, spec 010): the tokens of the account issued before revoked_from are refused. One row per
-- account, moved forward by each revocation; the history lives in the audit. The account and the tenant belong to other domains, so only
-- their ids are kept (Annex J, no cross-schema keys); a Platform Administrator has no tenant.
CREATE TABLE operations_cost.account_session_cutoff (
    account_id    uuid        NOT NULL,
    tenant_id     uuid,
    revoked_from  timestamptz NOT NULL,
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_account_session_cutoff PRIMARY KEY (account_id)
);
