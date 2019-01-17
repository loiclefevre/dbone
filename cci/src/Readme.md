# Setup
## DB system creation
First you'll need to provision a DB System with the following characteristics:
- Extreme Performance
- Take last version (as of now 18.2.0.0)
- VM.Standard2.2 shape
- Enable Automatic Backup
- 256GB of storage
- Create also a pluggable database (PDB) with name *CCI*.

## APEX installation
You'll need to install APEX 18.X hence
- download it: https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
- install it: https://community.oracle.com/message/14983380#14983380

## Virtual Machine to host Oracle Rest Data Services (ORDS)
You'll then need to create a VM with the following characteristics:
- Oracle Linux 7.X (7.6 as of now)
- VM.Standard2.2 shape
- It must be in the very same VCN as the Db System :)
- You can leave the other default values

Once the VM is created, you can define a reserved IP for the VM.

## Oracle Rest Data Services (ORDS) installation
In the aforementioned VM, you'll need to deploy ORDS 18.X in Apache Tomcat 8.X as a best practice for managing APEX 18.X Rest Data Services.
- download Tomcat: https://tomcat.apache.org/download-80.cgi
- download ORDS: https://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
- install them:
  - Oracle documentation: https://docs.oracle.com/database/ords-17/AELIG/installing-REST-data-services.htm#AELIG7224
  - Oracle-base post: https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat

## Network configuration

### Oracle Cloud Infrastructure
You'll need to configure OCI security lists of the VCN to allow (for the moment) HTTP traffic (soon HTTPS) to the ports 8080 and 8081.

*As of now, the Db System provisioning should open the port 1521 to allow SQL Developer connection from your laptop. This requirement will disappear in the future, once the deployment via github / sqlplus is validated!*

### Oracle Linux Firewall
You'll also need to open the ports at the Operating System level with iptables in case of Oracle Linux 6 or Firewalld in case of Oracle Linux 7.

Example with OL6 as root:
```Bash
$ iptables-save > /tmp/iptables.orig  # save the current firewall rules
$ iptables -I INPUT 8 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT -m comment --comment "Required for APEX"
$ iptables -I INPUT 8 -p tcp -m state --state NEW -m tcp --dport 8081 -j ACCEPT -m comment --comment "Required for ORDS with Tomcat"
service iptables save  # save configuration
```

Example with OL7 as root:
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

## Manage Websites Certificates
To allow the database to connect to the respective Oracle Cloud REST API endpoints, you'll need to download and configure the certificates with Oracle database wallets.

Afterwards, you'll need to configure the database ACLs to allow the application to connect to the REST API endpoints 
