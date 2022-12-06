FROM oraclelinux:8
ARG REPO=testing
ARG PBM_VERSION=2.0.2-1
ARG PSMDB_VERSION=6.0.2-1
ARG PMM_VERSION=2.21.0-6

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/usr/sbin/init"]

RUN set -ex; \
    export GNUPGHOME="$(mktemp -d)"; \
    export PSMDB_REPO="$(echo "${PSMDB_VERSION}" | awk -F '.' '{print "psmdb-"$1$2}')" ; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A 99DB70FAE1D7CE227FB6488205B555B38483C65D 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1; \
    gpg --batch --export --armor 430BDF5C56E7C94E848EE60C1C4CBDCDCD2EFD2A > ${GNUPGHOME}/RPM-GPG-KEY-Percona; \
    gpg --batch --export --armor 99DB70FAE1D7CE227FB6488205B555B38483C65D > ${GNUPGHOME}/RPM-GPG-KEY-centosofficial; \
    gpg --batch --export --armor 94E279EB8D8F25B21810ADF121EA45AB2F86D6A1 > ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    rpmkeys --import ${GNUPGHOME}/RPM-GPG-KEY-Percona ${GNUPGHOME}/RPM-GPG-KEY-centosofficial ${GNUPGHOME}/RPM-GPG-KEY-EPEL-8; \
    curl -Lf -o /tmp/percona-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm; \
    rpmkeys --checksig /tmp/percona-release.rpm; \
    rpm -i /tmp/percona-release.rpm; \
    rm -rf "$GNUPGHOME" /tmp/percona-release.rpm; \
    rpm --import /etc/pki/rpm-gpg/PERCONA-PACKAGING-KEY; \
    percona-release enable pbm ${REPO} && \
    percona-release enable ${PSMDB_REPO} ${REPO} && \
    percona-release enable pmm2-client ${REPO} && \
    yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \   
    yum -y update && \
    yum -y install percona-server-mongodb-${PSMDB_VERSION}.el8 \
                   percona-server-mongodb-tools-${PSMDB_VERSION}.el8 \
                   percona-server-mongodb-server-${PSMDB_VERSION}.el8 \
                   percona-server-mongodb-mongos-${PSMDB_VERSION}.el8 \
                   percona-backup-mongodb-${PBM_VERSION}.el8 \
                   pmm2-client-${PMM_VERSION}.el8 && \ 
    systemctl enable mongod && \
    systemctl enable pbm-agent && \
    systemctl enable pmm-agent && \
    yum clean all; \
    rm -rf /var/cache/dnf /var/cache/yum /data/db && mkdir -p /data/db;

COPY conf/sysconfig/pbm-agent /etc/sysconfig/
COPY conf/sysconfig/mongod /etc/sysconfig/
EXPOSE 27017