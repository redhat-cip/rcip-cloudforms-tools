#!/bin/bash
#
# fcambi@redhat.com
#
# Description: That shell script sets up a complete cloudforms project on Openstack from an empty OSP-d 7.2 with only a project created
#
# Prerequisites: Create a project named cloudforms. Change the variables with your information, copy that script on a controller and source the RC file of the cloudforms project.
#
# Ssh to a controller
# Source the admin RC file
# Edit this file's first block of variables below
# Usage: ./setup_3nodes_cf.sh
#

#CHANGE ALL VARIABLES, those are just examples
#CLOUDFORMS_LATEST_QCOW2_URL="go to access.redhat.com -> download latest cloudforms and paste URL with token here"
#Example: https://access.cdn.redhat.com//content/origin/files/sha256/f1/f192c8b488431ec6e392f531671ecf85ee7d74d5de36eb1cb9b2ee0278d1b14b/cfme-rhos-5.5.0.13-2.x86_64.qcow2?_auth_=1454015285_772b8b5b0601c4289d8c837d53d5cdb4
CLOUDFORMS_LATEST_QCOW2_URL=""
#AUTHORIZED_SSH_IP="0.0.0.0/0" for all
AUTHORIZED_SSH_IP=""
#CF_IMAGE_NAME="Red Hat CloudForms (v. 4.0 for x86_64)" #This is just a name
CF_IMAGE_NAME=""
#MY_SSH_KEY="ssh-rsa replacethatincrediblelongkey jdoe@redhat.com"
MY_SSH_KEY=""
#KEY_NAME="John Doe" #your name here
KEY_NAME="" 
#USER_EMAIL="jdoe@redhat.com"
USER_EMAIL=""

#Check variables settings
for variable in CLOUDFORMS_LATEST_QCOW2_URL AUTHORIZED_SSH_IP CF_IMAGE_NAME MY_SSH_KEY KEY_NAME USER_EMAIL; do
    if [ -z "${!variable}" ]; then
        echo "${variable} is not set, please edit setup_3nodes_cf.sh and set it before running this script"
        exit 1
    fi
done

#CONSTANTS, no need to change but you might need to make some changes depending on your OSP-d config
PUB_NET_NAME="public" #IMPORTANT name of the external network, used to reserve and affect floating IPs
PRV_NET_NAME="private network"
PRV_SUB_NAME="private subnet"
RTR_GTW_NAME="Gateway"
CF_DB01_VOL_NAME="vol-cf-db01"
CF_DB01_NAME="cloudforms-DB01"
CF_UI01_VOL_NAME="vol-cf-ui01"
CF_UI01_NAME="cloudforms-UI01"
CF_WRK01_VOL_NAME="vol-cf-wrk01"
CF_WRK01_NAME="cloudforms-WRK01"
CF_WRK02_VOL_NAME="vol-cf-wrk02"
CF_WRK02_NAME="cloudforms-WRK02"
NB_INSTANCES="4"


############# Installation
# Download latest Openstack (QCOW2) image from access.redhat.com
echo -e "Downloading latest Cloudforms qcow2 image from access.redhat.com...\n"
wget "$CLOUDFORMS_LATEST_QCOW2_URL -O cfme-image.qcow2"

# Convert image to RAW:
echo -e "Converting image...\n"
qemu-img convert -f qcow2 -O raw cfme-image.qcow2 cfme-image.raw

# Override tenant variables for the project
OS_PROJECT_NAME="cloudforms_test"
OS_PROJECT_ID=$(openstack project create --description "test Cloudforms" --enable "cloudforms_test" | grep id | awk '{print $4}')
CF_USER_ID=$(openstack user create --project $OS_PROJECT_ID --password $OS_PROJECT_NAME --email $EMAIL --enable $OS_PROJECT_NAME | grep " id " | awk '{print $4}')
OS_TENANT_ID=$OS_PROJECT_ID
OS_TENANT_NAME=$OS_PROJECT_NAME
OS_USERNAME=$OS_PROJECT_NAME
OS_PASSWORD=$OS_PROJECT_NAME

# Upload the image to the projet and save its ID
echo -e "Uploading Cloudforms image...\n"
CF_IMAGE_ID=$(glance image-create --name "$CF_IMAGE_NAME" --disk-format raw --min-ram 6144 --file cfme-image.raw --is-protected true --progress --container-format bare | grep id | awk '{print $4}')

# Create the default security group
echo -e "Creating security groups...\n"
openstack security group create "Default Cloudforms" --description "Minimal rules for Cloudforms"
nova secgroup-add-rule "Default Cloudforms" icmp -1 -1 0.0.0.0/0
nova secgroup-add-rule "Default Cloudforms" tcp 443 443 0.0.0.0/0
nova secgroup-add-rule "Default Cloudforms" tcp 80 80 0.0.0.0/0
nova secgroup-add-rule "Default Cloudforms" tcp 22 22 $AUTHORIZED_SSH_IP
nova secgroup-list-rules "Default Cloudforms"
#You should have
#+-------------+-----------+---------+-------------------+--------------+
#| IP Protocol | From Port | To Port | IP Range          | Source Group |
#+-------------+-----------+---------+-------------------+--------------+
#| tcp         | 443       | 443     | 0.0.0.0/0         |              |
#| icmp        | -1        | -1      | 0.0.0.0/0         |              |
#| tcp         | 80        | 80      | 0.0.0.0/0         |              |
#| tcp         | 22        | 22      | $AUTHORIZED_SSH_IP|              |
#+-------------+-----------+---------+-------------------+--------------+

# Create a keypair
echo -e "Uploading keypair...\n"
echo "$MY_SSH_KEY" > mykey.pub
openstack keypair create --public-key mykey.pub "$KEY_NAME"
rm mykey.pub

#### Create network
# Get the ID of the public network
echo -e "Getting \"public\" network ID...\n"
PUB_NET_ID=$(neutron net-external-list | grep "$PUB_NET_NAME" | awk '{print $2}')

# Create a private network for the project and save the network ID
echo -e "Creating private network...\n"
NETWORK_ID=$(openstack network create "$PRV_NET_NAME" --no-share | grep " id " | awk '{print $4}')

# Create a router and save its ID
echo -e "Creating router...\n"
ROUTER_ID=$(neutron router-create "$RTR_GTW_NAME"  | grep " id " | awk '{print $4}')

# Create a subnet for that network and save its ID
echo -e "Creating private subnet...\n"
PRV_SUBNET_ID=$(neutron subnet-create --tenant-id "$OS_TENANT_ID" --name "$PRV_SUB_NAME" --gateway 192.168.0.254 --allocation-pool start=192.168.0.1,end=192.168.0.253 --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 "$NETWORK_ID" 192.168.0.0/24  | grep " id " | awk '{print $4}')

echo -e "Binding network interfaces...\n"
# Bind the public network as a gateway to the router
neutron router-gateway-set "$ROUTER_ID" "$PUB_NET_ID"

# Bind an interface from the router to the private network
neutron router-interface-add "$ROUTER_ID" "$PRV_SUBNET_ID"

# Create 4 volumes and save their IDS
echo -e "Creating $NB_INSTANCES volumes...\n"
CF_DB01_VOL_ID=$(openstack volume create --size 40 --description "Root volume for cloudforms VMDB" --image $CF_IMAGE_ID "$CF_DB01_VOL_NAME"  | grep " id " | awk '{print $4}')
CF_UI01_VOL_ID=$(openstack volume create --size 40 --description "Root volume for cloudforms WebUI" --image $CF_IMAGE_ID "$CF_UI01_VOL_NAME" | grep " id " | awk '{print $4}')
CF_WRK01_VOL_ID=$(openstack volume create --size 40 --description "Root volume for cloudforms Worker01" --image $CF_IMAGE_ID "$CF_WRK01_VOL_NAME"  | grep " id " | awk '{print $4}')
CF_WRK02_VOL_ID=$(openstack volume create --size 40 --description "Root volume for cloudforms Worker02" --image $CF_IMAGE_ID "$CF_WRK02_VOL_NAME"  | grep " id " | awk '{print $4}')

# Spawn 4 instances (DB, UI and Workers) and save their IDs
echo -e "Spawning $NB_INSTANCES instances...\n"
CF_DB01_ID=$(nova boot --image $CF_IMAGE_ID --flavor m1.large --security-groups "Default Cloudforms" --key-name "$KEY_NAME" --availability-zone nova --nic "net-id=$NETWORK_ID" --block-device-mapping "vda=$CF_DB01_VOL_ID::1" "$CF_DB01_NAME"  | grep " id " | awk '{print $4}')
CF_UI01_ID=$(nova boot --image $CF_IMAGE_ID --flavor m1.large --security-groups "Default Cloudforms" --key-name "$KEY_NAME" --availability-zone nova --nic "net-id=$NETWORK_ID" --block-device-mapping "vda=$CF_UI01_VOL_ID::1" "$CF_UI01_NAME"  | grep " id " | awk '{print $4}')
CF_WRK01_ID=$(nova boot --image $CF_IMAGE_ID --flavor m1.large --security-groups "Default Cloudforms" --key-name "$KEY_NAME" --availability-zone nova --nic "net-id=$NETWORK_ID" --block-device-mapping "vda=$CF_WRK01_VOL_ID::1" "$CF_WRK01_NAME"  | grep " id " | awk '{print $4}')
CF_WRK02_ID=$(nova boot --image $CF_IMAGE_ID --flavor m1.large --security-groups "Default Cloudforms" --key-name "$KEY_NAME" --availability-zone nova --nic "net-id=$NETWORK_ID" --block-device-mapping "vda=$CF_WRK02_VOL_ID::1" "$CF_WRK02_NAME"  | grep " id " | awk '{print $4}')

# Associate a floating IP to the UI and the DB (if the DB sync goes through public network)
echo -e "Associating floating IPs...\n"
CF_DB01_IP=$(openstack ip floating create "$PUB_NET_NAME" | grep " id " | awk '{print $4}')
openstack ip floating add "$CF_DB01_IP" "$CF_DB01_NAME"
CF_UI01_IP=$(openstack ip floating create "$PUB_NET_NAME" | grep " id " | awk '{print $4}')
openstack ip floating add "$CF_UI01_IP" "$CF_UI01_NAME"

echo -e "End of cloudforms setup\n"
