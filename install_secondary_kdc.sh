######################
# Slave KDC
######################

## Set parameters

KADMIN_PASS='<PASSWORD>'
TRUST_PASS='<PASSWORD>'

KDC_REALM='<KDC REALM>'
kdc_realm_lower_case=$(echo ${KDC_REALM} | tr '[A-Z]' '[a-z]')

AD_REALM='<AD REALM>'
ad_realm_lower_case=$(echo ${AD_REALM} | tr '[A-Z]' '[a-z]')

MASTER_KDC='< Master KDC DNS >'
SECONDARY_KDC=$(hostname -f)
S3_LOCATION='s3://<S3 BUCKET of your conf templates and keytab file>/kdc/conf/'
S3_KEYTAB='s3://<S3 BUCKET of your conf templates and keytab file>/kdc/keytabs/'
########

#### IMPORTANT ####
# COPY /etc/krb5.conf from S3 to Slave KDC
aws s3 cp ${S3_KEYTAB}krb5.keytab /tmp/krb5.keytab

if [ -f "/etc/krb5.keytab" ]; then 
  sudo mv /etc/krb5.keytab /etc/krb5.keytab.old
fi

sudo cp /tmp/krb5.keytab /etc/krb5.keytab

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

# Set password to kadmin/admin principal
sudo kadmin.local -q "cpw -pw $KADMIN_PASS kadmin/admin"
sudo kadmin.local -q "cpw -pw $KADMIN_PASS kadmin/$(hostname -f)"

# Create ACL to permit KPROPD access and copy of replicated KDC
sudo bash -c "echo host/${MASTER_KDC}@${KDC_REALM} > /var/kerberos/krb5kdc/kpropd.acl"

# Disable use of kadmin on secondary KC
sudo systemctl disable kadmin

# Start krb5kdc and kprop
sudo systemctl start krb5kdc && sudo systemctl enable krb5kdc
sudo systemctl start kprop && sudo systemctl enable kprop
