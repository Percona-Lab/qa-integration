#!/bin/bash

# Configure Kerberos for replicaset setup
set -e

# Create krb5.conf
cat > /etc/krb5.conf << EOL
[libdefaults]
    default_realm = PERCONATEST.COM
    forwardable = true
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ignore_acceptor_hostname = true
    rdns = false
[realms]
    PERCONATEST.COM = {
        kdc_ports = 88
        kdc = kerberos
        admin_server = kerberos
    }
[domain_realm]
    .perconatest.com = PERCONATEST.COM
    perconatest.com = PERCONATEST.COM
    kerberos = PERCONATEST.COM
EOL

# Initialize Kerberos database only if it doesn't exist
if [ ! -f /var/lib/krb5kdc/principal ]; then
    kdb5_util -P password create -s
fi
# Add principals (ignore if they already exist)
kadmin.local -q "addprinc -pw password root/admin" 2>/dev/null || true
kadmin.local -q "addprinc -pw mongodb mongodb/rs101" 2>/dev/null || true
kadmin.local -q "addprinc -pw mongodb mongodb/rs102" 2>/dev/null || true
kadmin.local -q "addprinc -pw mongodb mongodb/rs103" 2>/dev/null || true
kadmin.local -q "addprinc -pw mongodb mongodb/127.0.0.1" 2>/dev/null || true
kadmin.local -q "addprinc -pw password1 pmm-test" 2>/dev/null || true

# Create extra replicaset member principals if needed
if [ "${COMPOSE_PROFILES}" = "extra" ]; then
    kadmin.local -q "addprinc -pw mongodb mongodb/rs201" 2>/dev/null || true
    kadmin.local -q "addprinc -pw mongodb mongodb/rs202" 2>/dev/null || true
    kadmin.local -q "addprinc -pw mongodb mongodb/rs203" 2>/dev/null || true
fi

kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs101@PERCONATEST.COM"
kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs102@PERCONATEST.COM"
kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs103@PERCONATEST.COM"
kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/127.0.0.1@PERCONATEST.COM"

if [ "${COMPOSE_PROFILES}" = "extra" ]; then
    kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs201@PERCONATEST.COM"
    kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs202@PERCONATEST.COM"
    kadmin.local -q "ktadd -k /keytabs/mongodb.keytab mongodb/rs203@PERCONATEST.COM"
fi

# Add pmm-test principal to keytab
kadmin.local -q "ktadd -k /keytabs/mongodb.keytab pmm-test@PERCONATEST.COM"

# Start KDC and keep it running
krb5kdc -n &
kadmind &
tail -f /dev/null 