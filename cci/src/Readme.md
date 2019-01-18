# Setup
Quick summary:
- A Db System will host the main CCI Oracle Database with APEX installed on it.
- A VM will host Oracle Rest Data Services (ORDS) installed on Tomcat (this requires Open JDK 1.8). ORDS requires to have APEX installed _first_ on the Db System.

![Cloud Center Interface architecture](./CCI-Architecture.png "Cloud Center Interface architecture")

## DB system creation
First you'll need to provision a DB System with the following characteristics:
- Extreme Performance
- Take last version (as of now 18.2.0.0)
- VM.Standard2.2 shape
- Enable Automatic Backup
- 256GB of storage
- Create also a pluggable database (PDB) with name *CCI*.

## APEX installation
You'll need to install APEX 18.X on the Db System as oracle user, hence:
- download it: https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
Because of the OTN license agreement requested, you'll need to download it on your local machine and then using sftp tranfer it on the VM to the oracle user home directory (/home/oracle).
```Bash
[oracle @CCI-DB ~] $ unzip apex_18.2.zip
```

- install it: https://community.oracle.com/message/14983380#
  Don't forget to source the environment:
```Bash
[oracle @CCI-DB ~] $ . oraenv
# ensure you have the right Database setup
[oracle @CCI-DB ~] $ cd apex
[oracle @CCI-DB apex] $ sqlplus /nolog
SQL> conn sys as sysdba
SQL> ALTER USER ANONYMOUS ACCOUNT UNLOCK;
SQL> ALTER SESSION SET CONTAINER=CCI;
SQL> @apexins.sql sysaux sysaux temp /i/
SQL> @apxchpwd.sql
SQL> @apex_rest_config.sql
SQL> @apex_epg_config.sql /root
SQL> EXEC DBMS_XDB.sethttpport(8080);
```

## Virtual Machine to host Oracle Rest Data Services (ORDS)
You'll then need to create a VM with the following characteristics:
- Oracle Linux 7.X (7.6 as of now)
- VM.Standard2.2 shape
- It must be in the very same VCN as the Db System :)
- You can leave the other default values

Once the VM is created, you can define a reserved IP for the VM.

You'll need to create the user account that will manage Tomcat and ORDS: oracle.

## Oracle Rest Data Services (ORDS) installation
In the aforementioned VM, you'll need to deploy ORDS 18.X in Apache Tomcat 8.X as a best practice for managing APEX 18.X Rest Data Services. 

- install Open JDK 1.8:
```Bash
[opc @CCI-VM ~] $ sudo yum install java -y
```

- download Tomcat: https://tomcat.apache.org/download-80.cgi
```Bash
[oracle @CCI-VM ~] $ wget http://www.mirrorservice.org/sites/ftp.apache.org/tomcat/tomcat-8/v8.5.37/bin/apache-tomcat-8.5.37.zip
[oracle @CCI-VM ~] $ unzip apache-tomcat-8.5.37.zip
```

- download ORDS: https://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
  Because of the OTN license agreement requested, you'll need to download it on your local machine and then using sftp tranfer it on the VM.
```Bash
[oracle @CCI-VM ~] $ unzip -d ords ords-18.4.0.354.1002.zip
```

- install them:
  - Oracle-base post: https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat
  - Oracle Rest Data Services documentation: https://docs.oracle.com/database/ords-17/AELIG/installing-REST-data-services.htm#AELIG7224
  - Apache Tomcat documentation: https://tomcat.apache.org/tomcat-8.5-doc/setup.html
  

## Network configuration

### Oracle Cloud Infrastructure
You'll need to configure OCI security lists of the VCN to allow (for the moment) HTTP traffic (soon HTTPS) to the ports 8080 and 8081.

*As of now, the Db System provisioning should open the port 1521 to allow SQL Developer connection from your laptop. This requirement will disappear in the future, once the deployment via github / sqlplus is validated!*

### Oracle Linux Firewall
You'll also need to open the ports at the Operating System level with iptables in case of Oracle Linux 6 or Firewalld in case of Oracle Linux 7.

Example with OL7 as root on the VM:
```Bash
$ firewall-cmd --permanent --zone=public --add-port=8080/tcp
$ firewall-cmd --permanent --zone=public --add-port=8081/tcp
$ firewall-cmd --reload
$ firewall-cmd --permanent --zone=public --list-ports
```

Example with OL6 as root on the Db System node(s):
```Bash
$ iptables-save > /tmp/iptables.orig  # save the current firewall rules
$ iptables -I INPUT 8 -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT -m comment --comment "Required for APEX"
$ service iptables save  # save configuration
```

## Schema creation
You'll then need to create the schema (and user) CCI and gives the roles. Please retrieve the files from this folder and *don't forget to change the password of user CCI!*

```Bash
$ sqlplus / as sysdba @sys_setup.sql
```

## Manage Websites Certificates
To allow the database to connect to the respective Oracle Cloud REST API endpoints, you'll need to download and configure the certificates with Oracle database wallets.

Connected on the Db system as oracle:
- download ![Oracle Cloud Certificate](./oracclecloud.com.cer "Oracle Cloud Certificate")
- install it using the following documentation https://oracle-base.com/articles/misc/utl_http-and-ssl
Don't forget to source the environment:
```Bash
[oracle @CCI-DB ~] $ . oraenv
# ensure you have the right Database setup
[oracle @CCI-DB ~] $ mkdir -p ~/wallet
[oracle @CCI-DB ~] $ orapki wallet create -wallet ~/wallet -pwd <YOUR PASSWORD> -auto_login
[oracle @CCI-DB ~] $ orapki wallet add -wallet ~/wallet -trusted_cert -cert "/host/oracle/oracclecloud.com.cer" -pwd <YOUR PASSWORD>
```

Afterwards, you'll need to configure the database ACLs to allow the application to connect to the REST API endpoints 

