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

# Run pending migrations + installation-config sync before booting.
# EasyPanel (and a plain `docker compose`) never runs the Procfile `release:`
# phase, so without this a deployed image ships new migrations that never apply.
# Safe because this stack runs a single rails/web container; keep RUN_MIGRATIONS
# unset/true only on the web service, not on extra workers sharing this entrypoint.
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "Running db:chatwoot_prepare (pending migrations + config loader)...."
  bundle exec rails db:chatwoot_prepare
fi

# Execute the main process of the container
exec "$@"
