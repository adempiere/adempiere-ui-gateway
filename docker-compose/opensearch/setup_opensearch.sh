#!/usr/bin/env sh

echo "Setup for allows increase size..."
curl --location --request PUT 'http://opensearch-node:9200/_all/_settings' --header 'Content-Type: application/json' --data '{"index.blocks.read_only_allow_delete": null}'
echo "Creating repository..."
curl --location --request PUT 'http://opensearch-node:9200/_snapshot/default-repository' --header 'Content-Type: application/json' --data '{"type": "fs","settings": {"location": "/mnt/snapshots"}}'
echo "Restoring snapshot..."
curl --location --request POST 'http://opensearch-node:9200/_snapshot/default-repository/1/_restore' --header 'Content-Type: application/json' --data ''
