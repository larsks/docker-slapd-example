FROM docker.io/alpine:latest

RUN apk add --update \
	openldap \
	openldap-clients \
	openldap-overlay-all \
	openldap-backend-all \
	\
	&& rm -rf /var/cache/apk \
	&& rm -f /etc/openldap/slapd.conf

COPY docker-entrypoint.sh /bin/docker-entrypoint.sh
COPY start-slapd.sh /bin/start-slapd.sh

ENTRYPOINT ["/bin/docker-entrypoint.sh"]

CMD ["start-slapd.sh"]
