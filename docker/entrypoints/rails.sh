#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

#install missing gems for local dev as we are using base image compiled for production
bundle install

BUNDLE="bundle check"

until $BUNDLE
do
  sleep 2;
done

# DO NOT run `rails db:migrate` / `db:chatwoot_prepare` / `db:prepare` here.
# On EasyPanel the health-check kills the container while the migration is still
# running, leaving a half-applied migration -> next boot fails with PG::DuplicateTable
# and the service crash-loops (happened 2026-09-04). Migrations on this fork are
# MANUAL: after deploy, run `bundle exec rails db:chatwoot_prepare` once from the
# service console. The `fork-guardrails` CI check enforces this.

# Execute the main process of the container
exec "$@"
