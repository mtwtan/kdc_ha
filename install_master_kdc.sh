######################
# Master KDC
######################

## Set parameters

KADMIN_PASS='<PASSWORD>'
TRUST_PASS='<PASSWORD>'

KDC_REALM='<KDC REALM>'
kdc_realm_lower_case=$(echo ${KDC_REALM} | tr '[A-Z]' '[a-z]')

AD_REALM='<AD REALM>'
ad_realm_lower_case=$(echo ${AD_REALM} | tr '[A-Z]' '[a-z]')

MASTER_KDC=$(hostname -f)
SECONDARY_KDC='<secondary kdc DNS>'
S3_LOCATION='s3://<S3 BUCKET of your conf templates and keytab file>/kdc/conf/'
S3_KEYTAB='s3://<S3 BUCKET of your conf templates and keytab file>/kdc/keytabs/'
########

## Copy krb5 and kdc conf template from S3
cd /tmp
aws s3 cp ${S3_LOCATION}krb5.conf.template /tmp/krb5.conf
aws s3 cp ${S3_LOCATION}kdc.conf.template /tmp/kdc.conf

## Install krb5
sudo yum install -y krb5-server krb5-libs krb5-workstation
sudo mkdir -p /var/log/kerberos

# Edit /etc/krb5.conf
sudo sed -i "s/<KDC REALM>/${KDC_REALM}/g" /tmp/krb5.conf
sudo sed -i "s/<AD REALM>/${AD_REALM}/g" /tmp/krb5.conf
sudo sed -i "s/<master kdc>/${MASTER_KDC}/g" /tmp/krb5.conf
sudo sed -i "s/<secondary kdc>/${SECONDARY_KDC}/g" /tmp/krb5.conf
sudo sed -i "s/<kdc realm lower case>/${kdc_realm_lower_case}/g" /tmp/krb5.conf
sudo sed -i "s/<ad realm lower case>/${ad_realm_lower_case}/g" /tmp/krb5.conf

# Edit /var/kerberos/krb5kdc/kdc.conf
sudo sed -i "s/<KDC REALM>/${KDC_REALM}/g" /tmp/kdc.conf

# Switch out krb5.conf and kdc.conf
sudo mv /var/kerberos/krb5kdc/kdc.conf /var/kerberos/krb5kdc/kdc.conf.orig
sudo mv /tmp/kdc.conf /var/kerberos/krb5kdc/kdc.conf
sudo chmod 400 /var/kerberos/krb5kdc/kdc.conf

sudo mv /etc/krb5.conf /etc/krb5.conf.orig
sudo mv /tmp/krb5.conf /etc/krb5.conf

# Create Kerberos database
sudo kdb5_util create -s

# Create admin ACL file
sudo bash -c 'echo "*/admin *" > /var/kerberos/krb5kdc/kadm5.acl'

# Set password to kadmin/admin principal that will be used by EMR
sudo kadmin.local -q "cpw -pw $KADMIN_PASS kadmin/admin"
sudo kadmin.local -q "cpw -pw $KADMIN_PASS kadmin/$(hostname -f)"

# Create principal and set password for the TGT for Cross-Realm Trust
sudo kadmin.local -q "add_principal -pw $TRUST_PASS krbtgt/${KDC_REALM}@${AD_REALM}"
sudo kadmin.local -q "add_principal -pw $TRUST_PASS krbtgt/${AD_REALM}@${KDC_REALM}"

# Start krb5kdc and kadmin service
sudo systemctl start krb5kdc && sudo systemctl enable krb5kdc
sudo systemctl start kadmin && sudo systemctl enable kadmin

# Create HOST principal for master KDC
sudo kadmin.local -q "add_principal -randkey host/$(hostname -f)"
sudo kadmin.local -q "ktadd host/$(hostname -f)"

# Create HOST principal for secondary KDC
sudo kadmin.local -q "add_principal -randkey host/${SECONDARY_KDC}"
sudo kadmin.local -q "ktadd host/${SECONDARY_KDC}"

## Test
# kinit kadmin/admin

# Copy krb5.keytab to S3 to be transferred to Secondary KDC
aws s3 cp /etc/krb5.keytab ${S3_KEYTAB}krb5.keytab
