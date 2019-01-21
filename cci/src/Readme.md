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
*Remark*: before starting, don't forget to unlock the following database user accounts to allow the proper installation of ORDS:
```SQL
SQL> alter user ORDS_METADATA account unlock;
SQL> alter user ORDS_PUBLIC_USER account unlock;
SQL> alter user APEX_PUBLIC_USER account unlock;
SQL> alter user APEX_REST_PUBLIC_USER account unlock;
```

In the aforementioned VM, you'll need to deploy ORDS 18.X in Apache Tomcat 8.X as a best practice for managing APEX 18.X Rest Data Services. 

- install Open JDK 1.8:
```Bash
[opc @CCI-VM ~] $ sudo yum install java -y
```

- download Tomcat: https://tomcat.apache.org/download-80.cgi
```Bash
[oracle @CCI-VM ~] $ wget http://www.mirrorservice.org/sites/ftp.apache.org/tomcat/tomcat-8/v8.5.37/bin/apache-tomcat-8.5.37.zip
```

- download ORDS: https://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html
  Because of the OTN license agreement requested, you'll need to download it on your local machine and then using sftp tranfer it on the VM.
```Bash
[oracle @CCI-VM ~] $ unzip -d ords ords-18.4.0.354.1002.zip
```

- install them:
  - Apache Tomcat documentation: https://tomcat.apache.org/tomcat-8.5-doc/setup.html
```Bash
[oracle @CCI-VM ~] $ unzip apache-tomcat-8.5.37.zip
[oracle @CCI-VM ~] $ cd apache-tomcat-8.5.37/conf
```

Change HTTP port to 8081 in the server.xml file:
```XML
    <Connector port="8081" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443"
               maxHttpHeaderSize="32000" />
```

You can now start the Apache Tomcat server:
```Bash
[oracle @CCI-VM ~] $ cd ../bin
[oracle @CCI-VM ~] $ ./catalina.sh start
```  

  - Oracle-base post: https://oracle-base.com/articles/misc/oracle-rest-data-services-ords-installation-on-tomcat
  - Oracle Rest Data Services documentation: https://docs.oracle.com/database/ords-17/AELIG/installing-REST-data-services.htm#AELIG7224

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

## Testing the configuration
From now on, you should be able to connect to APEX using ORDS by using the following URL: ![](http://VM public IP:8081/ords "http://VM public IP:8081/ords") 

![ORDS APEX Login screen](./ORDS%20APEX.png "APEX Login screen using ORDS")

## Manage Oracle Cloud Certificate
To allow the database to connect to the respective Oracle Cloud REST API endpoints, you'll need to download and configure the certificate with Oracle database wallets.

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

The configuration of database ACLs to allow the application to connect to the REST API endpoints is managed in the script ![sys_setup.sql](./sys_setup.sql "sys_setup.sql"): 
```SQL
exec dbms_network_acl_admin.create_acl(acl => 'idcs_apex_acl.xml',description => 'IDCS HTTP ACL', principal => 'APEX_180200', is_grant => TRUE,privilege => 'connect',start_date => null,end_date => null);
exec DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => 'idcs_apex_acl.xml',principal => 'APEX_180200',is_grant => true,privilege => 'resolve');
exec dbms_network_acl_admin.assign_acl(acl => 'idcs_apex_acl.xml', host => '*.oraclecloud.com', lower_port => 443, upper_port => 443);
```

## Schema creation
You'll then need to create the schema (and user) CCI and gives the roles. Please retrieve the files from this folder and *don't forget to change the password of user CCI!*

```Bash
$ sqlplus / as sysdba @sys_setup.sql
```

## OCI Advanced HTTP Signature Installation
One of the challenges to do OCI REST API calls is that all the calls require an Advanced HTTP Signature mechanism. This is easily implemented in Java as described in this ![OCI Advanced HTTP Signature](https://medium.com/db-one/oracle-cloud-infrastructure-advanced-http-signature-for-rest-api-70af85802656 "blog post").

## APEX Workspace Creation
Now that the CCI schema exists, you can create the CCI APEX workspace that we'll use to create and test REST API Services.


## CCI Schema DDL
The CCI ![schema DDL script](./cci_ddl.sql "schema DDL script") contains all the SQL code to create the tables used by the application. Simply connect to the pluggable database and run the script as user CCI.

## CCI Reference Data
The CCI ![reference data script](./reference_data.sql "reference data script") contains all the SQL DML to create the needed reference data used by the application. Simply connect to the pluggable database and run the script as user CCI.

## CCI PL/SQL packages

## CCI Job Scheduling

## CCI Data Administration


*Well done, you've successfully installed the Cloud Center Interface!*
