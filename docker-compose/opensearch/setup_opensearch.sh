#!/usr/bin/env sh

echo "Setup for allows increase size... ${OPENSEARCH_HOST}"
curl --location --request PUT "$OPENSEARCH_HOST}/_all/_settings" \
	--header 'Content-Type: application/json' \
	--data '{"index.blocks.read_only_allow_delete": null}'


echo "Creating repository..."
curl --location --request PUT "${OPENSEARCH_HOST}/_snapshot/default-repository" \
	--header 'Content-Type: application/json' \
	--data '{"type": "fs","settings": {"location": "/mnt/snapshots"}}'


echo "Restoring snapshot..."
curl --location --request POST "${OPENSEARCH_HOST}/_snapshot/default-repository/1/_restore" \
	--header 'Content-Type: application/json' \
	--data ''
