############################################
# Create cron job replication in Master KDC
############################################

sudo cat > /root/propagate_kdc_replica.sh <<'EOF'
#!/bin/sh

kdclist="< DNS of Secondary KDC >"

/usr/sbin/kdb5_util dump /var/kerberos/krb5kdc/slave_datatrans

for kdc in $kdclist
do
    /usr/sbin/kprop $kdc
done
EOF

sudo chmod +x /root/propagate_kdc_replica.sh

sudo cat >> /var/spool/cron/root <<'EOF'
*/2 * * * * /root/propagate_kdc_replica.sh
EOF
