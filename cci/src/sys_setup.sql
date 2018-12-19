-- Run this with the SYS account to setup CCI

alter session set container=CCI;

create user cci identified by My_Great_Pa55w0rd
DEFAULT TABLESPACE "USERS"
TEMPORARY TABLESPACE "TEMP"
QUOTA UNLIMITED ON "USERS";

-- ROLES
grant connect to cci;
grant create session to cci;
grant create table to cci;
grant create materialized view to cci;
grant create procedure to cci;
grant create trigger to cci;
grant create sequence to cci;
grant create job to cci;
grant create view to cci;
grant create materialized view to cci;


grant execute on SYS.DBMS_SCHEDULER to cci;
grant execute on apex_web_service to cci;
grant execute on apex_json to cci;
grant execute on dbms_crypto to cci;
grant execute on utl_encode to cci;
grant execute on utl_raw to cci;
grant execute on utl_http to cci;
grant execute on dbms_network_acl_admin to cci;

grant select on dba_network_acls to cci;

exec dbms_network_acl_admin.create_acl(acl => 'idcs_apex_acl.xml',description => 'IDCS HTTP ACL', principal => 'APEX_180200', is_grant => TRUE,privilege => 'connect',start_date => null,end_date => null);
exec DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl => 'idcs_apex_acl.xml',principal => 'APEX_180200',is_grant => true,privilege => 'resolve');
exec dbms_network_acl_admin.assign_acl(acl => 'idcs_apex_acl.xml', host => '*.oraclecloud.com', lower_port => 443, upper_port => 443);

commit;
