# The migration runner: Liquibase and the PostgreSQL driver, both at a fixed version.
# Liquibase 5 does not ship the driver, so it is installed here.
FROM liquibase/liquibase:5.0.4
RUN lpm add postgresql@42.7.13 --global
# The migrations travel with the runner, so applying them needs no volume and the runner and the SQL it applies are
# versioned together (plan D-02). The build context is the repository root.
WORKDIR /workspace
COPY --chown=liquibase:liquibase changelog ./changelog
COPY --chown=liquibase:liquibase 01_ddl ./01_ddl
COPY --chown=liquibase:liquibase 02_dml ./02_dml
COPY --chown=liquibase:liquibase 03_dcl ./03_dcl
COPY --chown=liquibase:liquibase 04_tcl ./04_tcl
COPY --chown=liquibase:liquibase 05_rollbacks ./05_rollbacks
