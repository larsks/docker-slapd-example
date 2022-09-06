#!/bin/sh

: "${LDAP_DEBUG_LEVEL:=0}"
: "${LDAP_URIS:="ldap:// ldaps:// ldapi://"}"

exec $LDAP_LIBEXECDIR/slapd -u ldap \
	-d${LDAP_DEBUG_LEVEL} \
	-h "${LDAP_URIS}" \
	${LDAP_EXTRA_ARGS}
