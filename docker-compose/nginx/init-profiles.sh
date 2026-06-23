#!/bin/sh
set -e

# We use the COMPOSE_PROFILES variable injected from the host
ACTIVE_PROFILES=${COMPOSE_PROFILES:-none}
export ACTIVE_PROFILES
echo "Compose profiles: [$ACTIVE_PROFILES]"

# Convert to sh-compatible array (without using <<<)
profiles_list=$(echo "$ACTIVE_PROFILES" | tr ',' ' ')

ENABLE_DICTIONARY_RS=false
ENABLE_ENVOY_BACKEND=false
ENABLE_ENVOY_PROCESSOR=false
ENABLE_ENVOY_REPORT=false
ENABLE_LANDING_PAGE=false
ENABLE_S3_GATEWAY_RS=false
ENABLE_VUE=false
ENABLE_ZK=false
# Check if the variable is empty or equal to “all”.
if [[ -z "$ACTIVE_PROFILES" || "$ACTIVE_PROFILES" == "none" || "$ACTIVE_PROFILES" == "all" ]]; then
  echo "The variable is empty or equal to 'all'"
  ENABLE_DICTIONARY_RS=true
  ENABLE_ENVOY_BACKEND=true
  ENABLE_ENVOY_PROCESSOR=true
  ENABLE_ENVOY_REPORT=true
  ENABLE_LANDING_PAGE=true
  ENABLE_S3_GATEWAY_RS=true
  ENABLE_VUE=true
  ENABLE_ZK=true
else
  # Iterate over each profile in the array
  for profile in $profiles_list; do
    case "$profile" in
      "" | "¨none" | "all")
        echo "The variable is empty or equal to 'all'."
        ENABLE_DICTIONARY_RS=true
        ENABLE_ENVOY_BACKEND=true
        ENABLE_ENVOY_PROCESSOR=true
        ENABLE_ENVOY_REPORT=true
        ENABLE_LANDING_PAGE=true
        ENABLE_S3_GATEWAY_RS=true
        ENABLE_VUE=true
        ENABLE_ZK=true
      ;;
      "auth")
        echo "The variable contains the profile 'auth'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_VUE=true
        ENABLE_ZK=true
      ;;
      "cache")
        echo "The variable contains the profile 'cache'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_DICTIONARY_RS=true
        ENABLE_VUE=true
      ;;
      "report")
        echo "The variable contains the profile 'report'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_ENVOY_REPORT=true
        ENABLE_VUE=true
        ENABLE_ZK=true
      ;;
      "scheduler")
        echo "The variable contains the profile 'scheduler'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_ENVOY_PROCESSOR=true
        ENABLE_VUE=true
        ENABLE_ZK=true
      ;;
      "storage")
        echo "The variable contains the profile 'storage'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_S3_GATEWAY_RS=true
        ENABLE_VUE=true
      ;;
      "vue")
        echo "The variable contains the profile 'vue'."
        ENABLE_ENVOY_BACKEND=true
        ENABLE_VUE=true
      ;;
      "zk")
        echo "The variable contains the profile 'zk'."
        ENABLE_ZK=true
      ;;
      *)
        echo "The variable does not contain an unknown value: $profile."
      ;;
    esac
  done
fi


# Create the directory if it does not exist
echo "created /etc/nginx/api_upstreams_conf.d/ and /etc/nginx/api_conf.d/ folders"
mkdir -p /etc/nginx/api_upstreams_conf.d/
mkdir -p /etc/nginx/api_conf.d/

# cleans the files inside the folders
echo "cleans the files inside the folders /etc/nginx/api_upstreams_conf.d/ and /etc/nginx/api_conf.d/ folders"
rm -f /etc/nginx/api_upstreams_conf.d/*
rm -f /etc/nginx/api_conf.d/*


# Check if the variable is empty or equal to "all"
if [[ -z "$ACTIVE_PROFILES" || "$ACTIVE_PROFILES" == "all" ]]; then
  echo "copy all locations and upstreams files"
  cp /etc/nginx/templates/upstreams/*.conf /etc/nginx/api_upstreams_conf.d/
  cp /etc/nginx/templates/locations/*.conf /etc/nginx/api_conf.d/
else
  if [[ "$ENABLE_DICTIONARY_RS" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/dictionary_rs.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/dictionary_rs.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_ENVOY_BACKEND" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/adempiere_backend.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/adempiere_backend.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_ENVOY_PROCESSOR" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/adempiere_processor.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/adempiere_processor.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_ENVOY_REPORT" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/adempiere_report.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/adempiere_report.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_LANDING_PAGE" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/landing_page.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/landing_page.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_S3_GATEWAY_RS" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/s3_gateway_rs.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/s3_gateway_rs.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_VUE" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/adempiere_vue.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/adempiere_vue.conf /etc/nginx/api_conf.d/
  fi
  if [[ "$ENABLE_ZK" == "true" ]]; then
    cp /etc/nginx/templates/upstreams/adempiere_zk.conf /etc/nginx/api_upstreams_conf.d/
    cp /etc/nginx/templates/locations/adempiere_zk.conf /etc/nginx/api_conf.d/
  fi
fi


# prints the nginx directory as a result
tree -d /etc/nginx/


# Validate configuration
if ! nginx -t; then
  echo "Error: Invalid Nginx config"
  exit 1
fi

echo "Setup apply sucessfully"
