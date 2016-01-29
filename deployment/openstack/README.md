# cloudformsOnOpenstack-setup
Automated Multi appliances setup of cloudforms  on Openstack

# Description
That shell script sets up a complete cloudforms project on Openstack from an empty OSP-d 7.2 with only a project created

# Prerequisites
- Ssh to a controller
- Source the admin RC file
- git clone git@github.com:toddoli/cloudformsOnOpenstack-setup.git
- edit setup_3nodes_cf.sh and replace the variables in the first block
- Launch ./setup_3nodes_cf.sh

# Post Installation
## Configure the master DB appliance

```
ssh root@$CF_DB01_IP #default password smartvm
appliance_console
```
- Menu combination 8 - 1 - 1 - Y - 99

Choose a password
- Set a hostname for this appliance

Menu combination 4 - db01.cloudforms.showcase.rcip.redhat.com

- Wait for the appliance to boot the webUI (can take several minutes)
- Login to the webUI
- Create a new zone for the databases (i.e "Databases") and switch this appliance to be part of that zone.

## Configure the WebUI appliance
```
ssh root@$CF_UI01_IP
appliance_console
```
 
- Set a hostname for this appliance

 Menu 4 -> cloudforms.showcase.rcip.redhat.com

- Attach to the DB01 as external DB

 Menu 8 - 2 - [private IP of cloudforms-DB01] - root - smartvm - /var/www/miq/vmdb/certs/v2_key (default) - 2 - [private IP of cloudforms-DB01] - vmdb_production (default) - root - [DB password]

## Configure the Workers appliance

- display console (through Horizon) of cloudforms-WRK01
```
appliance_console
```

- Set a hostname for this appliance

Menu 4 -> cloudforms.showcase.rcip.redhat.com

- Attach to the DB01 as external DB

Menu 8 - 2 - [private IP of cloudforms-DB01] - root - smartvm - /var/www/miq/vmdb/certs/v2_key (default) - 2 - [private IP of cloudforms-DB01] - vmdb_production (default) - root - [DB password]

-  Repeat for cloudforms-WRK02

## Deactivate/Activate useful roles on the appliances
### Database
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

### Web UI
go to https://$CF_UI01_IP
go to configure -> configuration -> Region 99 -> Zones -> Default Zone -> Server : EVM [9900000000000x] (current) -> change those attributes:
- Appliance Name: cloudforms-UI01
- Zone: WebUI
- Server Roles: check "Automation Engine","Database Operations","Reporting","Scheduler","User Interface","Web Services"

### Workers (x2)
go to configure -> configuration -> Region 99 -> Zones -> Default Zone -> Server : EVM [9900000000000x] (last2) -> change those attributes:
- Appliance Name: cloudforms-WRK0x
- Zone: WORKERS
- Server Roles: check "Automation Engine","Database Operations","Reporting","Scheduler","User Interface","Web Services"

## Add a region

Run this script on the second openstack region and configure all appliances but with those information:
- Choose a lower region number (i.e 1)
- Fetch the security key of one of region 99's appliances

go to https://$CF_UI01_IP (from region 1, not 99)
- Activate the "Database Synchonisation" role on the DB appliance and configure the synchonisation worker with the infos of region 99's DB.
