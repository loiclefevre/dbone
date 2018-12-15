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
For the other (main) functions, install them as following:
```SQL
create or replace FUNCTION signGetRequest( p_date_header in varchar2, p_path in varchar2, p_host_header in varchar2, p_compartment_ocid in varchar2, p_administrator_ocid in varchar2, p_administrator_key_fingerprint in varchar2, p_administrator_private_key in varchar2) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.signGetRequest (java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String) return java.lang.String';

/

create or replace FUNCTION signHeadRequest( p_date_header in varchar2, p_path in varchar2, p_host_header in varchar2, p_compartment_ocid in varchar2, p_administrator_ocid in varchar2, p_administrator_key_fingerprint in varchar2, p_administrator_private_key in varchar2) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.signHeadRequest (java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String) return java.lang.String';

/

create or replace FUNCTION signDeleteRequest( p_date_header in varchar2, p_path in varchar2, p_host_header in varchar2, p_compartment_ocid in varchar2, p_administrator_ocid in varchar2, p_administrator_key_fingerprint in varchar2, p_administrator_private_key in varchar2) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.signDeleteRequest (java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String) return java.lang.String';

/

create or replace FUNCTION signPutRequest( p_date_header in varchar2, p_path in varchar2, p_host_header in varchar2, p_body in varchar2, p_compartment_ocid in varchar2, p_administrator_ocid in varchar2, p_administrator_key_fingerprint in varchar2, p_administrator_private_key in varchar2) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.signPutRequest (java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String) return java.lang.String';

/

create or replace FUNCTION signPostRequest( p_date_header in varchar2, p_path in varchar2, p_host_header in varchar2, p_body in varchar2, p_compartment_ocid in varchar2, p_administrator_ocid in varchar2, p_administrator_key_fingerprint in varchar2, p_administrator_private_key in varchar2) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.signPostRequest (java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String,java.lang.String) return java.lang.String';

/
```
## Example: listing users defined in OCI IAM
```SQL
set define off
set serveroutput on size unlimited

create or replace function listUsers( p_identity_domain_name in varchar2 ) return CLOB is
  g_wallet_path VARCHAR2(200):= 'file:/home/oracle/wallet';    -- Replace with DB Wallet location
  g_wallet_pwd VARCHAR2(200):= null;                           -- Replace with DB Wallet location
  g_OCI_API_VERSION VARCHAR2(16):= '20160918';
  l_url VARCHAR2(512);
  l_response CLOB; -- JSON Response
  l_date_header varchar2(128);
  l_host_header varchar2(128);
  l_service_uri varchar2(512);
  l_users_filter varchar2(512);
  l_method varchar2(16):='get';
  l_tenant_ocid identity_domains.tenant_ocid%TYPE;
  l_region identity_domains.region%TYPE;
  l_administrator_ocid identity_domains.administrator_ocid%TYPE;
  l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;
  l_administrator_private_key identity_domains.administrator_private_key%TYPE;
begin
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = p_identity_domain_name;
      
      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      apex_web_service.g_request_headers(1).name := 'date';
      apex_web_service.g_request_headers(1).value := l_date_header;
      
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      apex_web_service.g_request_headers(2).name := 'host';
      apex_web_service.g_request_headers(2).value := l_host_header;
  
      l_service_uri := '/' || g_OCI_API_VERSION || '/users';
      l_users_filter := 'compartmentId=' || replace(l_tenant_ocid,':','%3A') || '&' || 'limit=50';
      
      apex_web_service.g_request_headers(3).name := 'Authorization';
      apex_web_service.g_request_headers(3).value := signGetRequest( l_date_header, l_service_uri || '?' || l_users_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key );
      
      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_users_filter;    
      
      l_response := apex_web_service.make_rest_request( 
            p_url => l_url,
            p_http_method => 'GET',
            p_wallet_path => g_wallet_path
      );
      
    return l_response;
end;

/
```
Indeed some information are _obfuscated_ since they are stored in a table but you get the idea :)
