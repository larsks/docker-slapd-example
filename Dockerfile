FROM quay.io/centos/centos:stream8

COPY ltb.repo /etc/yum.repos.d
RUN rpm --import https://ltb-project.org/documentation/_static/RPM-GPG-KEY-LTB-project && \
	yum -y install epel-release && \
	yum -y install openldap-ltb openldap-ltb-contrib-overlays openldap-ltb-mdb-utils
RUN rm -rf /usr/local/openldap/etc/openldap/slapd.d

COPY docker-entrypoint.sh /bin/docker-entrypoint.sh
COPY start-slapd.sh /bin/start-slapd.sh

ENTRYPOINT ["/bin/docker-entrypoint.sh"]

CMD ["start-slapd.sh"]
