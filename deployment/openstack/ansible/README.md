# cloudformsOnOpenstack-setup
Automated Multi appliances setup of cloudforms on Openstack

# Description
That Ansible Playbook sets up a complete cloudforms project on Openstack from an empty OSP-d 7.2 with only a project created

# Prerequisites
- Create a tenant with a minimum of:
    - 5 Instances
    - 20 VCPUs
    - 40G RAM
    - 5 Floating IPs
    - 3 Security Groups
    - 1 Volume
    - 80G Volume Storage per instance
    - 1 imported public key

# Some examples are given but must be replaced with your values:
- edit deployment/openstack/ansible/heat-templates/environment.yaml and replace the values
- edit deployment/openstack/ansible/extra_vars.json and replace the values

# Launch
```
source my-cloudforms-tenant.rc
git clone git@github.com:redhat-cip/rcip-cloudforms-tools.git
cd rcip-cloudforms-tools/deployment/openstack/ansible
openstack stack create cloudforms-full -e heat-templates/environment.yaml -f yaml -t heat-templates/main.yaml
ansible-playbook -i dynamic_inventory.py main.yaml -u root -k -e "@extra_vars.json"
```

# Deactivate/Activate useful roles on the appliances
## Database
go to https://$CF_DB01_IP
login with admin/smartvm
go to configure -> configuration -> Region 99 -> Zones

- add a new zone: WebUI
- add a new zone: DB
- add a new zone: Workers


go to configure -> configuration -> Region 99 -> Zones -> Default Zone -> Server : EVM [9900000000000x] (current) -> change those attributes:
- Appliance Name: cloudforms-DB01
- Zone: DB
- Server Roles: check only " Database Operations "

click save (you should loose https connectivity in some seconds)

## Web UI
go to https://$CF_UI01_IP
go to configure -> configuration -> Region 99 -> Zones -> Default Zone -> Server : EVM [9900000000000x] (current) -> change those attributes:
- Appliance Name: cloudforms-UI01
- Zone: WebUI
- Server Roles: check "Automation Engine","Database Operations","Reporting","Scheduler","User Interface","Web Services"

## Workers
go to configure -> configuration -> Region 99 -> Zones -> Default Zone -> Server : EVM [9900000000000x] (last2) -> change those attributes:
- Appliance Name: cloudforms-WRK0x
- Zone: WORKERS
- Server Roles: check "Automation Engine","Database Operations","Reporting","Scheduler","User Interface","Web Services"

# Add a region

Run this script on the second openstack region and configure all appliances but with those information:
- Set a lower region number in your environment.yaml file (i.e. 1)
- Fetch the security key of one of region 99's appliances

go to https://$CF_UI01_IP (from the new region, not 99)
- Activate the "Database Synchonisation" role on the DB appliance and configure the synchonisation worker with the infos of region 99's DB.
