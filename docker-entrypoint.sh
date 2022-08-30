#!/bin/sh

: ${LDAP_LIMIT_FILES:=4096}

ulimit -n "${LDAP_LIMIT_FILES}"

# This is a dumb path but it's the compiled-in default
# (used by slapd for the ldapi socket).
install -d -m 700 -o ldap -g ldap /var/lib/openldap/run

if ! [ -d /etc/openldap/slapd.d ]; then
	mkdir /etc/openldap/slapd.d

	# Initial slapd with a configuration that will write a PID file
	# to a known location, and permit root access to cn=config over
	# an ldapi:// connection. This will permit us to start up a temporary
	# slapd instance in order to submit initialization files.
	cat <<-EOF > /etc/openldap/slapd.conf.init
	database config
	access to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
	EOF

	# Convert the stub slapd.conf into a cn=config directory configuration.
	slaptest -f /etc/openldap/slapd.conf.init -F /etc/openldap/slapd.d

	# Start a temporary slapd instance in the background.
	slapd -d1 -h ldapi:/// &
	slapd_pid=$!

	# Import the core schema
	ldapadd -Y EXTERNAL -H ldapi:// -f /etc/openldap/schema/core.ldif

	for initfile in /docker-entrypoint.d/*; do
		[ -f "$initfile" ] || continue

		rc=0

		case "$initfile" in
			*.sh)	sh "$initfile"
				rc=$?
				;;

			*.ldif)	ldapadd -Y EXTERNAL -H ldapi:// -f "$initfile"
				rc=$?
				;;

			*.ldifm) ldapmodify -Y EXTERNAL -H ldapi:// -f "$initfile"
				rc=$?
				;;

			*.schema)
				schemaname="$(cat initfile)"
				ldapadd -Y EXTERNAL -H ldapi:// -f "/etc/openldap/schema/$schemaname.ldif"
				rc=$?
				;;

			*)	echo "Unsupported extension: $initfile"
				rc=1
				;;
		esac
		
		if [ "$rc" -ne 0 ]; then
			echo "FAILED: $initfile" >&2
			exit 1
		else
			echo "SUCCESS: $initfile"
		fi
	done

	kill "$slapd_pid"
	chown -R ldap:ldap /etc/openldap/slapd.d /var/lib/openldap

fi

exec "$@"
