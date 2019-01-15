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
You'll need to configure OCI security lists to allow (for the moment) HTTP traffic (soon HTTPS) to the Tomcat port (default: 8080 or 8081 in case you installed Tomcat inside the Db System VM to not conflict with APEX PL/SQL Gateway).

### Oracle Linux Firewall
You'll also need to open the ports at the Operating System level with iptables in case of Oracle Linux 6 or Firewalld in case of Oracle Linux 7.

Example with OL6 as root:
```Bash
$ iptables-save > /tmp/iptables.orig  # save the current firewall rules
$ iptables -I INPUT 8 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT -m comment --comment "Required for APEX"
$ iptables -I INPUT 8 -p tcp -m state --state NEW -m tcp --dport 8081 -j ACCEPT -m comment --comment "Required for ORDS with Tomcat"
service iptables save  # save configuration
```

## Schema creation
You'll then need to create the schema (and user) CCI and gives the roles.

```Bash
$ sqlplus / as sysdba @sys_setup.sql
```

## Manage Certificates
