#!/bin/bash

set -euo pipefail

readonly MAX_CLIENT_NAME_LENGTH=64
readonly DEFAULT_OUTPUT_DIR="/home/ubuntu/clientovpns"

usage() {
	cat <<'EOF'
Generate an OpenVPN client profile manually from the server PKI.

Usage:
  sudo ./manual-client-ovpn.sh --client <name> [options]

Required:
  --client <name>              Client name. Allowed: letters, numbers, "_" and "-"

Options:
  --output-dir <path>          Output directory for the .ovpn file
                               Default: /home/ubuntu/clientovpns
  --cert-days <days>           Client certificate validity in days
                               Default: 3650
  --ifconfig-push <ip>         Write a fixed VPN IP into CCD
                               Example: 10.188.0.20
  --ifconfig-mask <mask>       Netmask for ifconfig-push
                               Default: 255.255.255.0
  --iroute <network>           Optional downstream subnet network
                               Example: 192.168.72.0
  --iroute-mask <mask>         Netmask for iroute
                               Example: 255.255.255.0
  -h, --help                   Show this help

Examples:
  sudo ./manual-client-ovpn.sh --client Winston_home_pi4

  sudo ./manual-client-ovpn.sh \
    --client Winston_home_pi4 \
    --ifconfig-push 10.188.0.20

  sudo ./manual-client-ovpn.sh \
    --client Winston_home_pi4 \
    --ifconfig-push 10.188.0.20 \
    --iroute 192.168.72.0 \
    --iroute-mask 255.255.255.0
EOF
}

fatal() {
	echo "[ERROR] $*" >&2
	exit 1
}

info() {
	echo "[INFO] $*"
}

is_root() {
	[[ ${EUID:-$(id -u)} -eq 0 ]]
}

is_valid_client_name() {
	local name="$1"
	[[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ ${#name} -le $MAX_CLIENT_NAME_LENGTH ]]
}

is_ipv4() {
	local ip="$1"
	local IFS=.
	local -a octets
	read -r -a octets <<<"$ip"
	[[ ${#octets[@]} -eq 4 ]] || return 1
	local octet
	for octet in "${octets[@]}"; do
		[[ $octet =~ ^[0-9]+$ ]] || return 1
		((octet >= 0 && octet <= 255)) || return 1
	done
}

require_file() {
	local path="$1"
	[[ -f "$path" ]] || fatal "Required file not found: $path"
}

get_tls_mode() {
	if grep -qs '^tls-crypt-v2 ' /etc/openvpn/server/server.conf; then
		echo "tls-crypt-v2"
	elif grep -qs '^tls-crypt ' /etc/openvpn/server/server.conf; then
		echo "tls-crypt"
	elif grep -qs '^tls-auth ' /etc/openvpn/server/server.conf; then
		echo "tls-auth"
	else
		echo "none"
	fi
}

append_tls_block() {
	local outfile="$1"
	local tls_mode="$2"
	local tmpkey=""

	case "$tls_mode" in
	tls-crypt-v2)
		tmpkey=$(mktemp /etc/openvpn/server/tls-crypt-v2-client.XXXXXX)
		openvpn --tls-crypt-v2 /etc/openvpn/server/tls-crypt-v2.key \
			--genkey tls-crypt-v2-client "$tmpkey"
		{
			echo "<tls-crypt-v2>"
			cat "$tmpkey"
			echo "</tls-crypt-v2>"
		} >>"$outfile"
		rm -f "$tmpkey"
		;;
	tls-crypt)
		{
			echo "<tls-crypt>"
			cat /etc/openvpn/server/tls-crypt.key
			echo "</tls-crypt>"
		} >>"$outfile"
		;;
	tls-auth)
		{
			echo "key-direction 1"
			echo "<tls-auth>"
			cat /etc/openvpn/server/tls-auth.key
			echo "</tls-auth>"
		} >>"$outfile"
		;;
	none)
		:
		;;
	*)
		fatal "Unsupported TLS mode: $tls_mode"
		;;
	esac
}

CLIENT=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
CERT_DAYS=3650
IFCONFIG_PUSH_IP=""
IFCONFIG_PUSH_MASK="255.255.255.0"
IROUTE_NETWORK=""
IROUTE_MASK=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--client)
		CLIENT="${2:-}"
		shift 2
		;;
	--output-dir)
		OUTPUT_DIR="${2:-}"
		shift 2
		;;
	--cert-days)
		CERT_DAYS="${2:-}"
		shift 2
		;;
	--ifconfig-push)
		IFCONFIG_PUSH_IP="${2:-}"
		shift 2
		;;
	--ifconfig-mask)
		IFCONFIG_PUSH_MASK="${2:-}"
		shift 2
		;;
	--iroute)
		IROUTE_NETWORK="${2:-}"
		shift 2
		;;
	--iroute-mask)
		IROUTE_MASK="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		fatal "Unknown argument: $1"
		;;
	esac
done

is_root || fatal "Run this script as root."
[[ -n "$CLIENT" ]] || fatal "Missing required argument: --client"
is_valid_client_name "$CLIENT" || fatal "Invalid client name. Use letters, numbers, '_' or '-', max $MAX_CLIENT_NAME_LENGTH chars."
[[ "$CERT_DAYS" =~ ^[0-9]+$ ]] && [[ "$CERT_DAYS" -ge 1 ]] || fatal "Invalid --cert-days value: $CERT_DAYS"

if [[ -n "$IFCONFIG_PUSH_IP" ]]; then
	is_ipv4 "$IFCONFIG_PUSH_IP" || fatal "Invalid --ifconfig-push IPv4 address: $IFCONFIG_PUSH_IP"
	is_ipv4 "$IFCONFIG_PUSH_MASK" || fatal "Invalid --ifconfig-mask IPv4 mask: $IFCONFIG_PUSH_MASK"
fi

if [[ -n "$IROUTE_NETWORK" ]]; then
	is_ipv4 "$IROUTE_NETWORK" || fatal "Invalid --iroute network: $IROUTE_NETWORK"
	[[ -n "$IROUTE_MASK" ]] || fatal "--iroute requires --iroute-mask"
	is_ipv4 "$IROUTE_MASK" || fatal "Invalid --iroute-mask IPv4 mask: $IROUTE_MASK"
fi

require_file /etc/openvpn/server/client-template.txt
require_file /etc/openvpn/server/easy-rsa/easyrsa
require_file /etc/openvpn/server/easy-rsa/pki/ca.crt
require_file /etc/openvpn/server/server.conf

mkdir -p "$OUTPUT_DIR"
mkdir -p /etc/openvpn/server/ccd

if [[ -f "/etc/openvpn/server/easy-rsa/pki/issued/${CLIENT}.crt" ]]; then
	fatal "Client certificate already exists: $CLIENT"
fi

info "Generating client certificate for $CLIENT"
(
	cd /etc/openvpn/server/easy-rsa
	export EASYRSA_CERT_EXPIRE="$CERT_DAYS"
	./easyrsa --batch build-client-full "$CLIENT" nopass
)

CLIENT_CERT="/etc/openvpn/server/easy-rsa/pki/issued/${CLIENT}.crt"
CLIENT_KEY="/etc/openvpn/server/easy-rsa/pki/private/${CLIENT}.key"
OUTFILE="${OUTPUT_DIR%/}/${CLIENT}.ovpn"

require_file "$CLIENT_CERT"
require_file "$CLIENT_KEY"

info "Writing ${OUTFILE}"
cp /etc/openvpn/server/client-template.txt "$OUTFILE"
{
	echo "<ca>"
	cat /etc/openvpn/server/easy-rsa/pki/ca.crt
	echo "</ca>"
	echo "<cert>"
	awk '/BEGIN/,/END CERTIFICATE/' "$CLIENT_CERT"
	echo "</cert>"
	echo "<key>"
	cat "$CLIENT_KEY"
	echo "</key>"
} >>"$OUTFILE"

append_tls_block "$OUTFILE" "$(get_tls_mode)"

if [[ -n "$IFCONFIG_PUSH_IP" || -n "$IROUTE_NETWORK" ]]; then
	CCD_FILE="/etc/openvpn/server/ccd/${CLIENT}"
	info "Writing CCD file ${CCD_FILE}"
	{
		[[ -n "$IFCONFIG_PUSH_IP" ]] && echo "ifconfig-push ${IFCONFIG_PUSH_IP} ${IFCONFIG_PUSH_MASK}"
		[[ -n "$IROUTE_NETWORK" ]] && echo "iroute ${IROUTE_NETWORK} ${IROUTE_MASK}"
	} >"$CCD_FILE"
fi

OWNER_USER="${SUDO_USER:-root}"
OWNER_GROUP="$OWNER_USER"
if id "$OWNER_USER" >/dev/null 2>&1; then
	chown "$OWNER_USER:$OWNER_GROUP" "$OUTFILE" || true
fi
chmod 600 "$OUTFILE"

info "Done"
echo "Client: ${CLIENT}"
echo "Profile: ${OUTFILE}"
if [[ -n "$IFCONFIG_PUSH_IP" ]]; then
	echo "Fixed VPN IP: ${IFCONFIG_PUSH_IP}"
fi
if [[ -n "$IROUTE_NETWORK" ]]; then
	echo "iroute: ${IROUTE_NETWORK} ${IROUTE_MASK}"
	echo "Note: if this subnet must be reachable from the server/LAN side, you may also need a matching 'route' in /etc/openvpn/server/server.conf."
fi
echo "No OpenVPN service restart was performed."
