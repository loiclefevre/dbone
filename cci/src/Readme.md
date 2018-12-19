# Setup
## DB system creation
First you'll need to provision a DB System (Extreme Performance 18.X). Do create also a pluggable database called CCI.

## APEX installation
You'll need to install APEX 18.X hence
- download it: https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html
- install it: https://community.oracle.com/message/14983380#14983380

## Schema creation
You'll then need to create the schema (and user) CCI and gives the roles.

```Bash
$ sqlplus / as sysdba @sys_setup.sql
```

## Manage Certificates
