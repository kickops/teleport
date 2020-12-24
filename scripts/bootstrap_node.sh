#!/bin/bash

# The following variables needs to be modifed for each teleport clusters.
# Please contact cloudinfra team if you do ot have the information
AUTH_URL="<TELEPORT_AUTH_LB_DNS>"
AUTH_TOKEN="<UUID-TOKEN>"

# Labels in 'key=value' format. 
#       Allowed Keys:   GROUP_NAME & ENVIRONMENT
#       Allowed Values: GROUP_NAME: app-dev, app-ops, app-dba, soc, infra
#                       ENVIRONMENT: staging, production, test
GROUP_NAME="<GROUP-NAME>"
ENVIRONMENT="<ENVIRONEMNT>"


rm -rf /var/lib/teleport/*

LOCAL_IP=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
LOCAL_HOSTNAME=`curl http://169.254.169.254/latest/meta-data/local-hostname`

# Install the teleport package
distro=`head -1 /etc/os-release | cut -d = -f2`
if [ "$distro" == '"Ubuntu"' ]; 
then
    wget https://get.gravitational.com/teleport-ent_5.0.1_amd64.deb && dpkg -i teleport-ent_5.0.1_amd64.deb
else
    yum install -y https://get.gravitational.com/teleport-ent-5.0.1-1.x86_64.rpm
fi

useradd -r teleport -d /var/lib/teleport
# Add teleport user to adm group to read and write logs
usermod -a -G adm teleport
mkdir -p /run/teleport/ /var/lib/teleport /etc/teleport.d
chmod 0700 /var/lib/teleport
chown -R teleport:adm /run/teleport /var/lib/teleport /etc/teleport.d/
chown -R teleport:adm /var/lib/teleport
touch /etc/teleport.yaml
chmod 664 /etc/teleport.yaml

# Teleport config file for a Node
cat > /etc/teleport.yaml <<EOF
teleport:
  auth_token: ${AUTH_TOKEN}
  nodename: ${LOCAL_HOSTNAME}
  advertise_ip: ${LOCAL_IP}
  log:
    output: syslog
    severity: INFO
  data_dir: /var/lib/teleport
  storage:
    type: dir
    path: /var/lib/teleport/backend
  auth_servers:
    - ${AUTH_URL}:3025
auth_service:
  enabled: no
ssh_service:
  enabled: yes
  listen_addr: 0.0.0.0:3022
  labels:
        group: ${GROUP_NAME}
        environment: ${ENVIRONMENT}
  pam:
        enabled: true
        service_name: "teleport"
proxy_service:
  enabled: no
EOF

##Teleport PAM Configuration ##
cat > /etc/pam.d/teleport <<EOF
account   required   pam_exec.so /etc/pam-exec.d/teleport_acct
session   required   pam_motd.so
session   required   pam_permit.so
EOF

###sudo Access Group
groupadd teleport-admin 
cat > /etc/sudoers.d/teleport <<EOF
%teleport-admin ALL=(ALL) NOPASSWD:ALL
EOF

##pam execution script for user creation and access management
mkdir -p /etc/pam-exec.d
cat > /etc/pam-exec.d/teleport_acct <<EOF
#!/bin/sh
COMMENT="User ${TELEPORT_USERNAME} with roles ${TELEPORT_ROLES} created by Teleport."
id -u "${TELEPORT_LOGIN}" > /dev/null 2>&1 || /usr/sbin/useradd -m -g teleport-admin -c "${COMMENT}" "${TELEPORT_LOGIN}" > /dev/null 2>&1
exit 0
EOF
chmod +x /etc/pam-exec.d/teleport_acct

systemctl daemon-reload
service teleport start

