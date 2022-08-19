#!/bin/sh

exec /usr/sbin/slapd -u ldap \
	${LDAP_DEBUG_LEVEL:+-d${LDAP_DEBUG_LEVEL}} \
	-h "${LDAP_URIS}" \
	${LDAP_EXTRA_ARGS}
