set define off

-- Create Cloud Center Interfacee tables

-- Identity Domains
-- Will store all managed identity domains information
create table identity_domains (
    name varchar2(64) not null primary key,
    region varchar2(64) not null,
    description varchar2(128),
    idcs_identifier varchar2(128),
    cloud_account varchar2(128),
    tenant_ocid varchar2(128) not null,
    administrator_name varchar2(128) not null,
    administrator_password varchar2(128) not null,
    creation_date varchar2(64),
	  client_id varchar2(64),
	  client_secret varchar2(64),
    administrator_ocid varchar2(256),
    administrator_key_fingerprint varchar2(256),
    administrator_prvate_key varchar2(4000),
    default_key_fingerprint varchar2(256),
    default_public_key_pem varchar2(4000),
    oci_idp_ocid varchar2(256)
);
