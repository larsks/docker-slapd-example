#!/bin/sh

: "${LDAP_INIT_DEBUG_LEVEL:=0}"
: "${LDAP_LIMIT_FILES:=4096}"

. /etc/docker/distro.conf

PATH="${LDAP_SBINDIR}:${LDAP_BINDIR}:${PATH}"
export PATH

DIE() {
	echo "FAILED: $*" >&2
	exit 1
}

slapd_is_up() {
	ldapsearch -Y EXTERNAL -H ldapi:// -b "" \
		-s base objectclass=\* namingcontexts > /dev/null 2>&1
}

if [ -n "$LDAP_LIMIT_FILES" ]; then
	ulimit -n "${LDAP_LIMIT_FILES}"
fi

install -d -m 700 -o ldap -g ldap "${LDAP_DATADIR}/run"

if ! [ -d "${LDAP_SYSCONFDIR}/slapd.d" ]; then
	mkdir "${LDAP_SYSCONFDIR}/slapd.d"

	if [ -f /docker-entrypoint.d/slapd.dump ]; then
		# Restore from a slapd dump produced with slapcat
		slapadd	-n 0 -F "${LDAP_SYSCONFDIR}/slapd.d" \
			-l /docker-entrypoint.d/slapd.dump -d1 ||
			DIE "failed to restore from slapd.dump"
	else
		# Initial slapd with a configuration that will write a PID file
		# to a known location, and permit root access to cn=config over
		# an ldapi:// connection. This will permit us to start up a temporary
		# slapd instance in order to submit initialization files.
		cat <<-EOF > "${LDAP_SYSCONFDIR}/slapd.conf.init"
		database config
		access to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
		EOF

		# Convert the stub slapd.conf into a cn=config directory configuration.
		slaptest -f "${LDAP_SYSCONFDIR}/slapd.conf.init" \
			-F "${LDAP_SYSCONFDIR}/slapd.d" ||
			DIE "failed to initialize slapd configuration"

		# Add core schema
		slapadd -n 0 -l "${LDAP_SYSCONFDIR}/schema/core.ldif" \
			-F "${LDAP_SYSCONFDIR}/slapd.d" ||
			DIE "failed to load core schema"
	fi

	# Start a temporary slapd instance in the background.
	${LDAP_SLAPD_PATH} -d${LDAP_INIT_DEBUG_LEVEL} -h ldapi:/// &
	slapd_pid=$!

	until slapd_is_up; do
		echo "waiting for slapd..."
		sleep 1
	done

	find /docker-entrypoint.d -name slapd.dump -prune -o -type f -print |
	while read -r initfile; do
		[ -f "$initfile" ] || continue

		echo "Processing: $initfile"

		rc=0

		case "$initfile" in
			*.sh)	sh "$initfile"
				rc=$?
				;;

			*.ldif)	ldapadd -Y EXTERNAL -H ldapi:// -f "$initfile"
				rc=$?
				;;

			*.ldifm)
				ldapmodify -Y EXTERNAL -H ldapi:// -f "$initfile"
				rc=$?
				;;

			*.schema)
				schemaname="$(cat "$initfile")"
				ldapadd -Y EXTERNAL -H ldapi:// \
					-f "${LDAP_SYSCONFDIR}/schema/$schemaname.ldif"
				rc=$?
				;;

			*)	echo "Unknown filetype: $initfile"
				rc=1
				;;
		esac
		
		if [ "$rc" -ne 0 ]; then
			DIE "error processing $initfile"
		fi

		echo "SUCCESS: $initfile"
	done || exit

	kill "$slapd_pid"
	chown -R ldap:ldap "${LDAP_SYSCONFDIR}/slapd.d" "${LDAP_DATADIR}"

fi

exec "$@"
