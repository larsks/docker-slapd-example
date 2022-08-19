#!/bin/sh -x

: ${LDAP_LIMIT_FILES:=4096}

ulimit -n "${LDAP_LIMIT_FILES}"

install -d -m 700 -o ldap -g ldap /var/lib/openldap/run
chown -R ldap:ldap /var/lib/openldap

if ! [ -d /etc/openldap/slapd.d ]; then
	mkdir /etc/openldap/slapd.d

	cat <<-EOF > /etc/openldap/slapd.conf.init
	pidfile /var/lib/openldap/run/slapd.pid

	database config
	access to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
	EOF

	slaptest -f /etc/openldap/slapd.conf.init -F /etc/openldap/slapd.d
	slapd -h ldapi:///

	ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/core.ldif
	for ldif in /docker-entrypoint.d/cn=config/*.ldif; do
		[ -f "$ldif" ] || continue
		if ! ldapadd -Y EXTERNAL -H ldapi:// -f "$ldif"; then
			echo "ERROR: failed to process $ldif" >&2
			exit 1
		fi
	done

	kill $(cat /var/lib/openldap/run/slapd.pid)
	chown -R ldap:ldap /etc/openldap/slapd.d

fi

exec "$@"
