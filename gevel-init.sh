#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

"${psql[@]}" --dbname="$DB" < /usr/local/pgsql/share/contrib/gevel.sql
