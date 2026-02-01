CREATE DATABASE keycloak;
CREATE DATABASE grafana;

-- Create read-only monitoring user for postgres_exporter
CREATE USER postgres_exporter WITH PASSWORD 'changeme_exporter_password';

-- Grant connection permissions to all databases
GRANT CONNECT ON DATABASE tav TO postgres_exporter;
GRANT CONNECT ON DATABASE keycloak TO postgres_exporter;
GRANT CONNECT ON DATABASE grafana TO postgres_exporter;

-- Grant monitoring role to postgres_exporter in each database
\c tav
GRANT pg_monitor TO postgres_exporter;

\c keycloak
GRANT pg_monitor TO postgres_exporter;

\c grafana
GRANT pg_monitor TO postgres_exporter;
