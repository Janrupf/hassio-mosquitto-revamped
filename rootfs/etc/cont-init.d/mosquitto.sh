#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Configures mosquitto
# ==============================================================================
readonly ACL="/etc/mosquitto/acl"
readonly USER_DATABASE="/etc/mosquitto/users.json"
readonly SYSTEM_USER="/data/system_user.json"
declare cafile
declare certfile
declare discovery_password
declare keyfile
declare password
declare service_password
declare ssl
declare username

function add_user {
  local current_json
  local username_u="$1"
  local password_u="$2"

  current_json="$(cat "${USER_DATABASE}")"

  jq \
   --arg username "${username_u}" \
   --arg password "${password_u}" \
   '.[. | length] |= . + {"username": $ARGS.named["username"], "password": $ARGS.named["password"]}' <<< "${current_json}" > "${USER_DATABASE}"
}

# Read or create system account data
if ! bashio::fs.file_exists "${SYSTEM_USER}"; then
  discovery_password="$(pwgen 64 1)"
  service_password="$(pwgen 64 1)"

  # Store it for future use
  bashio::var.json \
    homeassistant "^$(bashio::var.json password "${discovery_password}")" \
    addons "^$(bashio::var.json password "${service_password}")" \
    > "${SYSTEM_USER}"
else
  # Read the existing values
  discovery_password=$(bashio::jq "${SYSTEM_USER}" ".homeassistant.password")
  service_password=$(bashio::jq "${SYSTEM_USER}" ".addons.password")
fi

# Create the user database
echo "[]" > "${USER_DATABASE}"

# Set up discovery user
add_user "homeassistant" "${discovery_password}"
echo "user homeassistant" >> "${ACL}"

# Set up service user
add_user "addons" "${service_password}"
echo "user addons" >> "${ACL}"

# Set username and password for the broker
for login in $(bashio::config 'logins|keys'); do
  bashio::config.require.username "logins[${login}].username"
  bashio::config.require.password "logins[${login}].password"

  username=$(bashio::config "logins[${login}].username")
  password=$(bashio::config "logins[${login}].password")

  bashio::log.info "Setting up user ${username}"
  add_user "${username}" "${password}"
  echo "user ${username}" >> "${ACL}"
done

keyfile="/ssl/$(bashio::config 'keyfile')"
certfile="/ssl/$(bashio::config 'certfile')"
cafile="/ssl/$(bashio::config 'cafile')"
if bashio::fs.file_exists "${certfile}" \
  && bashio::fs.file_exists "${keyfile}";
then
  bashio::log.info "Certificates found: SSL is available"
  ssl="true"
  if ! bashio::fs.file_exists "${cafile}"; then
    cafile="${certfile}"
  fi
else
  bashio::log.info "SSL is not enabled"
  ssl="false"
fi

# Generate mosquitto configuration.
bashio::var.json \
  cafile "${cafile}" \
  certfile "${certfile}" \
  debug "^$(bashio::config 'debug')" \
  customize "^$(bashio::config 'customize.active')" \
  customize_folder "$(bashio::config 'customize.folder')" \
  keyfile "${keyfile}" \
  require_certificate "^$(bashio::config 'require_certificate')" \
  ssl "^${ssl}" \
  | tempio \
    -template /usr/share/tempio/mosquitto.gtpl \
    -out /etc/mosquitto/mosquitto.conf
