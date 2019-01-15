# Setup
## DB system creation
First you'll need to provision a DB System (Extreme Performance 18.X). Do create also a pluggable database called CCI.

## APEX installation
You'll need to install APEX 18.X hence
- download it: https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
- install it: https://community.oracle.com/message/14983380#14983380

## Oracle Rest Data Services (ORDS) installation
You'll also need to install ORDS 18.X as a best practice for managing APEX 18.X Rest Data Services in Apache Tomcat 8.X; either in a dedicated VM or inside the DbSystem VM:
- download Tomcat: https://tomcat.apache.org/download-80.cgi
- download ORDS: https://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
- install them:
  - Oracle documentation: https://docs.oracle.com/database/ords-17/AELIG/installing-REST-data-services.htm#AELIG7224
  - Oracle-base post: https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat

## Network configuration
### Oracle Cloud Infrastructure
### Oracle Linux Firewall

## Schema creation
You'll then need to create the schema (and user) CCI and gives the roles.

```Bash
$ sqlplus / as sysdba @sys_setup.sql
```

## Manage Certificates
