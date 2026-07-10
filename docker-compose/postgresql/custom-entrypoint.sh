#!/usr/bin/env bash
#
# Custom entrypoint for the ADempiere PostgreSQL image.
#
# It launches sync-credentials.sh in the background (it self-waits for Postgres to accept
# connections, then re-applies role passwords from the environment) and then hands off to the
# stock postgres entrypoint unchanged. Running the sync in the background guarantees it never
# blocks or alters PostgreSQL's own startup: if the sync fails for any reason, Postgres still
# starts normally.
#
# This makes credential changes (edit env + stop-all + start-all) take effect on restart,
# which the default image only does on the first initdb.
set -e

/usr/local/bin/sync-credentials.sh &

exec docker-entrypoint.sh "$@"
