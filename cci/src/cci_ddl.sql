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
    administrator_private_key varchar2(4000),
    default_key_fingerprint varchar2(256),
    default_public_key_pem varchar2(4000),
    oci_idp_ocid varchar2(256)
);

comment on table identity_domains  is 'Contains all the identity domains managed by the Cloud Center Interface.';

comment on column identity_domains.name is 'Identity domain name.';
comment on column identity_domains.region is 'Identity domain region (example: us-ashburn-1).';
comment on column identity_domains.description is 'Identity domain description.';
comment on column identity_domains.idcs_identifier is 'Identity domain IDCS identifier (example: idcs-xxxxxxxxxxxxxxxxxxxxxxx).';
comment on column identity_domains.cloud_account is 'Identity domain Cloud Account (example: cacct-yyyyyyyyyyyyyyyyyyyyyyyyyy).';
comment on column identity_domains.tenant_ocid is 'Identity domain Tenant OCID (example: ocid1.tenancy.oc1..abcdefghijklmnop...).';
comment on column identity_domains.administrator_name is 'Identity domain administrator name. This is a valid Oracle Cloud user used for REST API Basic authentication to Oracle Cloud Metering REST API.';
comment on column identity_domains.administrator_password is 'Identity domain administrator password.';
comment on column identity_domains.creation_date is 'Identity domain creation date, filled automatically by CCI.';
comment on column identity_domains.client_id is 'IDCS application OAuth2 Client Id used by CCI to perform IDCS administration tasks.';
comment on column identity_domains.client_secret is 'IDCS application OAuth2 Client Secret used by CCI to perform IDCS administration tasks.';
comment on column identity_domains.administrator_ocid is 'OCI non federated User OCID belonging to the Administrators group.';
comment on column identity_domains.administrator_ocid is 'OCI non federated User OCID belonging to the Administrators group.';
comment on column identity_domains.administrator_key_fingerprint is 'One of the OCI non federated User''s key fingerprint.';
comment on column identity_domains.administrator_private_key is 'The associated OCI non federated User''s private key (RSA format).';
comment on column identity_domains.default_key_fingerprint is 'Key fingerprint of the default API Key uploaded when creating federated Users.';
comment on column identity_domains.default_public_key_pem is 'Default public API Key uploaded when creating federated Users (PEM format).';
comment on column identity_domains.oci_idp_ocid is 'OCI Identity Provier OCID (OCID of the IDCS Identity Provider).';


-- Log Messages
-- Used to store log messages for the PL/SQL packages
create table log_messages (
  id NUMBER GENERATED ALWAYS AS IDENTITY primary key,
  identity_domain varchar2(64) not null,
  message varchar2(4000) not null,
  log_date timestamp(9) default systimestamp not null
) 
ROW STORE COMPRESS ADVANCED;

comment on table log_messages  is 'Contains all the log messages from the Cloud Center Interface code.';

comment on column log_messages.id  is 'Auto generated row ID (primary key).';
comment on column log_messages.identity_domain  is 'Identity domain the message is referring to.';
comment on column log_messages.message  is 'The message (maximum 4,000 bytes).';
comment on column log_messages.log_date  is 'The message timestamp.';


-- Cloud Teams
-- Used to group cloud users into logical teams
create table cloud_teams (
name varchar2(128) not null,
country varchar2(128) not null);

alter table cloud_teams add constraint PK_cloud_teams primary key  (name,country);

comment on table cloud_teams  is 'Contains all the teams per country for grouping logically cloud users (can be used for reporting...).';

comment on column cloud_teams.name  is 'Team name.';
comment on column cloud_teams.country  is 'Team country.';


-- Cloud Groups
-- Contains the groups used by CCI. In case of new group, it will be created inside IDCS as an IDCS group (and numerous Administration roles will be automatically associated to it).
-- The group will be mapped to an OCI group (federation). Also each group is mapped to an OCI compartment that (for the moment) must be created manually.
-- There are 2 categories of groups:
-- -1- child of the Sandbox compartment
-- -2- child of the Projects compartment
create table cloud_groups (
    identity_domain_name varchar2(64) not null, 
	name varchar2(128) not null, 
	type varchar2(16) not null, 
	description varchar2(256) not null, 
	admin_role varchar2(5) not null, 
	creation_date date not null, 
	compartment_child_of varchar2(128) not null, 
	constraint pk_cloud_groups primary key (identity_domain_name, name) using index, 
	constraint fk_cloud_groups_id foreign key (identity_domain_name) references identity_domains (name)
);


comment on table cloud_groups  is 'Contains all the groups managed by CCI. All cloud users belong to one or more group(s).';

comment on column cloud_groups.identity_domain_name  is 'Identity domain this (IDCS) Group belongs to.';
comment on column cloud_groups.name  is 'Name of the (IDCS) Group.';
comment on column cloud_groups.type  is 'Group Type. As of now, only IDCS is supported.';
comment on column cloud_groups.description  is 'Group description.';
comment on column cloud_groups.admin_role  is 'Will this Group have all administration roles associated to it? ''true'' or ''false'' accepted.';
comment on column cloud_groups.creation_date  is 'Creation date of this group.';
comment on column cloud_groups.compartment_child_of  is 'OCI Parent compartment this group is related to.';












