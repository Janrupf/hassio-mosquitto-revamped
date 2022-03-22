protocol mqtt
# user root
log_dest stdout
log_type all
persistence true
persistence_location /data/

# Authentication plugin
plugin /usr/share/mosquitto/libmosq_ext_auth.so
plugin_opt_http_auth_endpoint http://supervisor/auth
plugin_opt_http_header X-Supervisor-Token: {{ env "SUPERVISOR_TOKEN" }}
plugin_opt_http_auth_kind post_json
plugin_opt_user_file /etc/mosquitto/users.json

{{ if .customize }}
include_dir /share/{{ .customize_folder }}
{{ end }}

listener 1883
protocol mqtt

listener 1884
protocol websockets

{{ if .ssl }}

# Follow SSL listener if a certificate exists
listener 8883
protocol mqtt
{{ if .cafile }}
cafile {{ .cafile }}
{{ else }}
cafile {{ .certfile }}
{{ end }}
certfile {{ .certfile }}
keyfile {{ .keyfile }}
require_certificate {{ .require_certificate }}

listener 8884
protocol websockets
{{ if .cafile }}
cafile {{ .cafile }}
{{ else }}
cafile {{ .certfile }}
{{ end }}
certfile {{ .certfile }}
keyfile {{ .keyfile }}
require_certificate {{ .require_certificate }}

{{ end }}
