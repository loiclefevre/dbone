# Oracle Cloud Infrastructure (OCI) Advanced HTTP Signature for OCI REST API integration in PL/SQL
Provides an helper to sign REST API requests performed in PL/SQL.

## Installation
Source properly your environment then invoke **loadjava** command line as following:
```Bash
$ loadjava -oci8 -user <user name>/<password>@//<server hostname or IP>:<port 1521?>/<database service name> -verbose tomitribe-http-signatures-1.0.jar
$ loadjava -oci8 -user <user name>/<password>@//<server hostname or IP>:<port 1521?>/<database service name> -verbose guava-23.0.jar
$ loadjava -oci8 -user <user name>/<password>@//<server hostname or IP>:<port 1521?>/<database service name> -verbose OCIRESTAPIHelper.java
```
Using your favorite SQL tool (SQLcl, SQL Developer, sqlplus...), create the appropriate PL/SQL functions:
```SQL
create or replace FUNCTION OCIRESTAPIHelper_About RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.about () return java.lang.String';

/
```
And test it (compiling the very first time):
```SQL
select OCIRESTAPIHelper_About from dual;
```
