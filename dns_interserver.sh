#!/usr/bin/env sh
#
# dns_interserver  —  acme.sh DNS‑01 hook for Interserver (REST /apiv2)
# Env:  export INTERSERVER_API_KEY="xxxxxxxxxxxxxxxx"

INTERSERVER_API="https://my.interserver.net/apiv2"

##### Validate INTERSERVER_API_KEY environment variable #####

# Load API key from acme.sh config if available
[ -f "$HOME/.acme.sh/account.conf" ] && . "$HOME/.acme.sh/account.conf"
[ -f "/acme.sh/account.conf" ] && . "/acme.sh/account.conf"

case "$INTERSERVER_API_KEY" in
  "") _err "INTERSERVER_API_KEY is not set."; return 1 ;;
esac

# Use printf to get the length in a POSIX-compliant way
_key_length=$(printf %s "$INTERSERVER_API_KEY" | wc -c | tr -d ' ')

if [ "$_key_length" -lt 12 ]; then
  _err "INTERSERVER_API_KEY is too short ($INTERSERVER_API_KEY)"
  return 1
fi

# Extract first 4 and last 4 chars manually
_first4=$(printf %s "$INTERSERVER_API_KEY" | cut -c1-4)
_last4=$(printf %s "$INTERSERVER_API_KEY" | rev | cut -c1-4 | rev)

_info "INTERSERVER_API_KEY is set (${_first4}...${_last4}) and has a length of ${_key_length}."


########  Public functions  ########

dns_interserver_add() {
  fulldomain="$1"        # _acme-challenge.example.com
  txtvalue="$2"

  if _get_root "$fulldomain"; then
    data=$(printf '{"name":"%s","type":"TXT","content":"%s","ttl":120}' \
                  "$fulldomain" "$txtvalue")
    _post "$data" "$INTERSERVER_API/dns/${_domain_id}" ||
      return 1
    _record_id=$(echo "$response" |
                 _egrep_o '"id":"?[0-9]+"' | head -n1 | tr -dc '0-9')
    _info "Added record $_record_id in zone $_domain"
  else
    return 1
  fi
}

dns_interserver_rm() {
  fulldomain="$1"
  txtvalue="$2"

  if _get_root "$fulldomain" \
     && _get_record_id "$fulldomain" "$txtvalue"; then   # <‑‑ pass FQDN
    _delete "$INTERSERVER_API/dns/${_domain_id}/${_record_id}" || return 1
    _info "Removed record $_record_id"
  fi
}

########  Private helpers  ########

_get_root() {                       # $1 = full FQDN
  domain="$1"
  i=2
  while [ "$i" -lt 8 ]; do         # walk up the labels: a.b.c -> b.c -> c
    test_domain="$(printf '%s' "$domain" | cut -d. -f"$i"-)"
    _debug "Trying zone $test_domain"

    _rest GET "$INTERSERVER_API/dns" || return 1

    # Split the JSON into one object per line, find matching "name":, grab "id":
    _domain_id=$(printf '%s' "$response" \
      | tr '{' '\n' \
      | grep "\"name\":\"$test_domain\"" \
      | _egrep_o '"id":"?[0-9]+"' \
      | head -n1 | tr -dc '0-9')

    if [ -n "$_domain_id" ]; then
      _domain="$test_domain"
      # sub‑domain part *before* the root zone (may be empty for apex):
      _sub_domain=$(printf '%s' "$domain" | sed "s/.$_domain\$//")   # strip root
      if [ -z "$_sub_domain" ]; then
        _sub_domain="_acme-challenge"                                # apex case
      elif ! printf '%s' "$_sub_domain" | grep -q '^_acme-challenge'; then
        _sub_domain="_acme-challenge.$_sub_domain"                   # prepend once
      fi
      _debug "Found zone $_domain id=$_domain_id; sub=$_sub_domain"
      return 0
    fi
    i=$((i+1))
  done
  _err "No root zone found for $domain"
  return 1
}

_get_record_id() {          # $1 = fqdn   $2 = txt content
  _rest GET "$INTERSERVER_API/dns/${_domain_id}" || return 1
  _record_id=$(printf '%s' "$response" \
    | tr '{' '\n' \
    | grep "\"name\":\"$1\"" \
    | grep "\"content\":\"$2\"" \
    | _egrep_o '"id":"?[0-9]+"' \
    | tr -dc '0-9' | head -n1)
  [ -n "$_record_id" ] || { _err "TXT record not found."; return 1; }
}

########  HTTP helpers  ########
_get()    { _rest GET    "$1"; }           # _get  URL
_post()   { _rest POST   "$2" "$1"; }      # _post BODY URL
_delete() { _rest DELETE "$1"; }           # _delete URL

_rest() {                                  # $1=METHOD $2=URL [$3=BODY]
  method="$1"; url="$2"; body="$3"
  response="$(_exec_curl "$method" "$url" "$body")" || return 1
  _debug2 "Response: $response"
}

_exec_curl() {
  _method="$1"
  _url="$2"
  _body="$3"

  _debug "Executing curl: $_method $_url"

  if [ -n "$_body" ]; then
    _debug "Sending body: $_body"
    curl -sS -X "$_method" \
         -H "X-API-KEY: $INTERSERVER_API_KEY" \
         -H "Content-Type: application/json" \
         --data "$_body" \
         "$_url"
  else
    curl -sS -X "$_method" \
         -H "X-API-KEY: $INTERSERVER_API_KEY" \
         -H "Content-Type: application/json" \
         "$_url"
  fi
}
