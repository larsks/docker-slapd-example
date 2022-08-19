#!/bin/sh -x

: ${LDAP_DOMAIN:=example.com}
: ${LDAP_DATA_DIRECTORY:=/var/lib/openldap/data}
: ${LDAP_RUN_DIRECTORY:=/run/openldap}
: ${LDAP_LIMIT_FILES:=4096}
: ${LDAP_LDAPI_SOCKET_PATH:=/run/openldap/ldap}
: ${LDAP_DEBUG_LEVEL:=1}
: ${LDAP_LDAPI_SOCKET_URI="ldapi://$(echo "$LDAP_LDAPI_SOCKET_PATH" | sed s,/,%2f,g)"}
: ${LDAP_URIS:="ldap:/// ldaps:/// ${LDAP_LDAPI_SOCKET_URI}"}

export LDAP_DOMAIN LDAP_DATA_DIRECTORY LDAP_RUN_DIRECTORY
export LDAP_URIS LDAP_DEBUG_LEVEL
export LDAP_LDAPI_SOCKET_PATH LDAP_LDAPI_SOCKET_URI

if [ -z "$LDAP_ROOT_PASSWORD" ]; then
	echo "ERROR: Missing LDAP_ROOT_PASSWORD" >&2
	exit 1
fi

install -d -m 700 -o ldap -g ldap "${LDAP_RUN_DIRECTORY}"
install -d -m 700 -o ldap -g ldap "${LDAP_DATA_DIRECTORY}"

ldap_suffix=$(echo "$LDAP_DOMAIN" | sed 's/\([^.]*\).\?/dc=\1,/g' | sed 's/,$//')

if ! [ -f /etc/openldap/slapd.d ]; then
	mkdir /etc/openldap/slapd.d

	cat > /etc/openldap/slapd.conf.init <<-EOF
	include         /etc/openldap/schema/core.schema

	pidfile         ${LDAP_RUN_DIRECTORY}/slapd.pid
	argsfile        ${LDAP_RUN_DIRECTORY}/slapd.args

	modulepath      /usr/lib/openldap
	moduleload      back_mdb.so
	database        config
	rootdn          cn=manager,cn=config
	rootpw		${LDAP_ROOT_PASSWORD}
	database        mdb
	maxsize         1073741824
	suffix          "${ldap_suffix}"
	rootdn          "cn=manager,${ldap_suffix}"
	rootpw          ${LDAP_ROOT_PASSWORD}
	directory       ${LDAP_DATA_DIRECTORY}
	index   objectClass     eq
	EOF

	slaptest -f /etc/openldap/slapd.conf.init -F /etc/openldap/slapd.d

	chown -R ldap:ldap /etc/openldap/slapd.d
fi

ulimit -n "${LDAP_LIMIT_FILES}"
exec "$@"
