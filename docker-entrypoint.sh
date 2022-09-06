#!/bin/sh

: "${LDAP_DATADIR:=/usr/local/openldap/var}"
: "${LDAP_INIT_DEBUG_LEVEL:=0}"
: "${LDAP_LIBEXECDIR:=/usr/local/openldap/libexec}"
: "${LDAP_LIMIT_FILES:=4096}"
: "${LDAP_SBINDIR:=/usr/local/openldap/sbin}"
: "${LDAP_BINDIR:=/usr/local/openldap/bin}"
: "${LDAP_SYSCONFDIR:=/usr/local/openldap/etc}"

PATH="${LDAP_SBINDIR}:${LDAP_BINDIR}:${PATH}"

export PATH LDAP_SYSCONFDIR LDAP_DATADIR LDAP_SBINDIR LDAP_LIBEXECDIR

DIE() {
	echo "FAILED: $*" >&2
	exit 1
}

slapd_is_up() {
	ldapsearch -Y EXTERNAL -H ldapi:// -b "" \
		-s base objectclass=\* namingcontexts > /dev/null 2>&1
}

ulimit -n "${LDAP_LIMIT_FILES}"

if ! [ -d ${LDAP_SYSCONFDIR}/openldap/slapd.d ]; then
	mkdir ${LDAP_SYSCONFDIR}/openldap/slapd.d

	# Initial slapd with a configuration that will write a PID file
	# to a known location, and permit root access to cn=config over
	# an ldapi:// connection. This will permit us to start up a temporary
	# slapd instance in order to submit initialization files.
	cat <<-EOF > ${LDAP_SYSCONFDIR}/openldap/slapd.conf.init
	database config
	access to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage
	EOF

	# Convert the stub slapd.conf into a cn=config directory configuration.
	slaptest -f ${LDAP_SYSCONFDIR}/openldap/slapd.conf.init -F ${LDAP_SYSCONFDIR}/openldap/slapd.d ||
		DIE "failed to initialize slapd configuration"

	# Start a temporary slapd instance in the background.
	${LDAP_LIBEXECDIR}/slapd -d${LDAP_INIT_DEBUG_LEVEL} -h ldapi:/// &
	slapd_pid=$!

	until slapd_is_up; do
		echo "waiting for slapd..."
		sleep 1
	done

	# Import the core schema
	ldapadd -Y EXTERNAL -H ldapi:// -f ${LDAP_SYSCONFDIR}/openldap/schema/core.ldif ||
		DIE "failed to load core schema"

	for initfile in /docker-entrypoint.d/*; do
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

			*.ldifm) ldapmodify -Y EXTERNAL -H ldapi:// -f "$initfile"
				rc=$?
				;;

			*.schema)
				schemaname="$(cat $initfile)"
				ldapadd -Y EXTERNAL -H ldapi:// -f "${LDAP_SYSCONFDIR}/openldap/schema/$schemaname.ldif"
				rc=$?
				;;

			*)	echo "Unsupported extension: $initfile"
				rc=1
				;;
		esac
		
		if [ "$rc" -ne 0 ]; then
			DIE "error processing $initfile"
		fi

		echo "SUCCESS: $initfile"
	done

	kill "$slapd_pid"
	chown -R ldap:ldap ${LDAP_SYSCONFDIR}/openldap/slapd.d ${LDAP_DATADIR}

fi

exec "$@"
