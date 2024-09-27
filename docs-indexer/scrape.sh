#!/bin/bash

set -e

# check for the existence of the $HEALTH_URL and $START_URL environment variables
if [ -z "$MEILISEARCH_HOST_URL" ] || [ -z "$START_URL" ]; then
    echo "Error: Required environment variables are not set."
    [ -z "$MEILISEARCH_HOST_URL" ] && echo "MEILISEARCH_HOST_URL is missing."
    [ -z "$START_URL" ] && echo "START_URL is missing."
    exit 1
fi

health_check() {
    local health_url="$1"
    local timeout=300  # 5 minute timeout
    local deadtime=2  # 2 seconds between checks
    local curl_timeout=1  # 1 second timeout for each check

    local start_time=$(date +%s)

    echo "Starting health check..."

    while true; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))

        if [ $elapsed_time -ge $timeout ]; then
            echo "Timeout reached. Health check failed."
            return 1
        fi

        # check if the health check url is responding
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" -m $curl_timeout "$health_url")

        if [ "$status_code" -eq 200 ]; then
            echo "Health check succeeded. Status code: 200"
            return 0
        else
            echo "Health check failed. Status code: $status_code"
            sleep $deadtime
        fi
    done
}

echo "Starting health check for Meilisearch..."

if ! health_check "${MEILISEARCH_HOST_URL}/health"; then
    echo "Health check for Meilisearch failed. Exiting."
    exit 1
fi

echo "Health check for Meilisearch succeeded."

echo "Starting health check for the start URL..."

if ! health_check "$START_URL"; then
    echo "Health check for the start URL failed. Exiting."
    exit 1
fi

echo "Health check for the start URL succeeded."

echo "Starting Scrape Job..."

# set the start_urls[0].url to the START_URL environment variable
jq ".start_urls[0].url = \"$START_URL\"" meilisearch-docs-scraper.config.json > output.json

# run the docs_scraper with the output.json file
pipenv run ./docs_scraper output.json 2>&1

echo "Scrape Job completed."

# exit with a success code
exit 0