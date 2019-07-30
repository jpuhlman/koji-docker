#!/bin/bash
# Copyright (C) 2019 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

set -xe
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

ECTKOJI=/etc/koji

if [ -e "$ECTKOJI"/globals.sh ] ; then
	source "$ECTKOJI"/globals.sh
else
	source "$SCRIPT_DIR"/globals.sh
fi
if [ -e "$ECTKOJI"/parameters.sh ] ; then
	source "$ECTKOJI"/parameters.sh
else
	source "$SCRIPT_DIR"/parameters.sh
fi

rm -f $COMMON_CONFIG/.done
# INSTALL KOJI
if [ -z "$(swupd bundle-list | grep koji)" ] ; then
	swupd bundle-add koji
fi
systemctl stop postgresql httpd kojira || true
## SETTING UP SSL CERTIFICATES FOR AUTHENTICATION

mkdir -p $COMMON_CONFIG/$(echo "$KOJI_PKI_DIR" | sed s,/etc/,,)
mkdir -p $(dirname $KOJI_PKI_DIR)
if [ -e "$KOJI_PKI_DIR" -a ! -L "$KOJI_PKI_DIR" ] ; then
	cp -a "$KOJI_PKI_DIR"/* $COMMON_CONFIG/$(echo $KOJI_PKI_DIR | sed s,/etc/,,)/
        rm -rf "$KOJI_PKI_DIR"
fi
if [ ! -L $KOJI_PKI_DIR ] ; then
	ln -s $COMMON_CONFIG/$(echo $KOJI_PKI_DIR | sed s,/etc/,,) $KOJI_PKI_DIR
fi
mkdir -p "$KOJI_PKI_DIR"/{certs,private}
RANDFILE="$KOJI_PKI_DIR"/.rand
dd if=/dev/urandom of="$RANDFILE" bs=256 count=1

if [ ! -e "$KOJI_PKI_DIR"/ssl.cnf ] ; then

# Certificate generation
cat > "$KOJI_PKI_DIR"/ssl.cnf <<- EOF
HOME                    = $KOJI_PKI_DIR
RANDFILE                = $RANDFILE

[ca]
default_ca              = ca_default

[ca_default]
dir                     = $KOJI_PKI_DIR
certs                   = \$dir/certs
crl_dir                 = \$dir/crl
database                = \$dir/index.txt
new_certs_dir           = \$dir/newcerts
certificate             = \$dir/%s_ca_cert.pem
private_key             = \$dir/private/%s_ca_key.pem
serial                  = \$dir/serial
crl                     = \$dir/crl.pem
x509_extensions         = usr_cert
name_opt                = ca_default
cert_opt                = ca_default
default_days            = 3650
default_crl_days        = 30
default_md              = sha256
preserve                = no
policy                  = policy_match

[policy_match]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[req]
default_bits            = 2048
default_keyfile         = privkey.pem
default_md              = sha256
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions         = v3_ca # The extensions to add to the self signed cert
string_mask             = MASK:0x2002

[req_distinguished_name]
countryName                     = Country Name (2 letter code)
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
localityName                    = Locality Name (eg, city)
0.organizationName              = Organization Name (eg, company)
organizationalUnitName          = Organizational Unit Name (eg, section)
commonName                      = Common Name (eg, your name or your server\'s hostname)
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_max                = 64

[req_attributes]
challengePassword               = A challenge password
challengePassword_min           = 4
challengePassword_max           = 20
unstructuredName                = An optional company name

[usr_cert]
basicConstraints                = CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer:always

[v3_ca]
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always
basicConstraints                = CA:true
EOF

fi

# Install kojid
swupd bundle-add koji

# Create mock folders and permissions
mkdir -p /etc/mock/koji
mkdir -p /var/lib/mock
chown -R root:mock /var/lib/mock

# Setup User Accounts
if [ -z "$(id kojibuilder)" ] ; then
	useradd -r kojibuilder
fi
usermod -G mock kojibuilder

# Kojid Configuration Files
if [[ "$KOJI_SLAVE_FQDN" = "$KOJI_MASTER_FQDN" ]]; then
	KOJI_TOP_DIR="$KOJI_DIR"
else
	KOJI_TOP_DIR="$KOJI_MOUNT_DIR"
fi
mkdir -p /config/kojid
if [ ! -L /etc/kojid ] ; then
	ln -s /config/kojid /etc/kojid
fi
if [ ! -e /etc/kojid/kojid.conf ] ; then
cat > /etc/kojid/kojid.conf <<- EOF
[kojid]
sleeptime=5
maxjobs=16
topdir=$KOJI_TOP_DIR
workdir=/tmp/koji
mockdir=/var/lib/mock
mockuser=kojibuilder
mockhost=generic-linux-gnu
user=$KOJI_SLAVE_FQDN
server=$KOJI_URL/kojihub
topurl=$KOJI_URL/kojifiles
use_createrepo_c=True
allowed_scms=$GIT_FQDN:$GIT_PATH$GIT_GETSOURCES
cert = $KOJI_PKI_DIR/$KOJI_SLAVE_FQDN.pem
ca = $KOJI_PKI_DIR/koji_ca_cert.crt
serverca = $KOJI_PKI_DIR/koji_ca_cert.crt
EOF
fi

if env | grep -q proxy; then
	echo "yum_proxy = $https_proxy" >> /etc/kojid/kojid.conf
	mkdir -p /etc/systemd/system/kojid.service.d
	cat > /etc/systemd/system/kojid.service.d/00-proxy.conf <<- EOF
	[Service]
	Environment=http_proxy=$http_proxy
	Environment=https_proxy=$https_proxy
	Environment=no_proxy=$no_proxy
	EOF
	systemctl daemon-reload
fi

mkdir -p /config/logs/kojid
if [ -f /var/log/kojid.log ] ; then
	mv /var/log/kojid.log /config/logs/kojid/
fi
touch /config/logs/kojid/kojid.log
if [ ! -L /var/log/kojid.log ] ; then
	ln -s /config/logs/kojid/kojid.log /var/log/kojid.log
fi
systemctl enable --now kojid
