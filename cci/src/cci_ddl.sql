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


-- Automatic_Shutdown_Compartment
-- List of OCI compartments scanned for automatic shutdown process
create table automatic_shutdown_compartment (
    identity_domain_name varchar2(128) not null, 
    compartment_name varchar2(256) not null, 
    compartment_ocid varchar2(256) not null, 
    constraint pk_automatic_shutdown_compartment primary key (identity_domain_name, compartment_name) using index, 
    constraint fk_automatic_shutdown_id foreign key (identity_domain_name) references identity_domains (name)
);

create index idx_fk_identity_domain on automatic_shutdown_compartment (identity_domain_name);


comment on table automatic_shutdown_compartment  is 'Contains all the OCI compartments monitored for Automatic Shutdown.';

comment on column automatic_shutdown_compartment.identity_domain_name  is 'Identity Domain of this OCI compartment.';
comment on column automatic_shutdown_compartment.compartment_name  is 'OCI compartment to monitor.';
comment on column automatic_shutdown_compartment.compartment_ocid  is 'OCI compartment OCID.';


-- Cloud Users
-- Contains all the Cloud Users managed by CCI
create table cloud_users (	
	identity_domain_name varchar2(64) not null, 
	team varchar2(128) not null, 
	country varchar2(128) not null, 
	given_name varchar2(128) not null, 
	family_name varchar2(128) not null, 
	email varchar2(128) not null, 
	administrator char(1) not null, 
	enabled char(1) default 'N' not null, 
	idcs_user_id varchar2(128), 
	oci_iam_user_id varchar2(128), 
	constraint pk_cloud_users primary key (identity_domain_name, email) using index, 
	constraint fk_team foreign key (team, country) references cloud_teams (name, country), 
	constraint fk_identity_domain foreign key (identity_domain_name) references identity_domains (name)
);

create index idx_fk_team on cloud_users (team, country);


comment on table cloud_users  is 'Contains all the Cloud Users managed by CCI. IDCS users are created using this table. Cloud user name will be created by concatenating given_name, a dot and family_name in lower case such as: mickey.mouse. Any non letter character must be replaced by a dot (''.'').';

comment on column cloud_users.identity_domain_name  is 'Identity Domain of this cloud user.';
comment on column cloud_users.team  is 'Related Cloud Team.';
comment on column cloud_users.country  is 'Country this user refers to.';
comment on column cloud_users.given_name  is 'User''s given name in lower case.';
comment on column cloud_users.family_name  is 'User''s family name in lower case.';
comment on column cloud_users.email  is 'User''s e-mail (it won''t be used as the user name to log to Oracle Cloud).';
comment on column cloud_users.administrator  is 'If ''Y'', this user is an administrator.';
comment on column cloud_users.enabled  is 'If ''Y'', this user is enabled.';
comment on column cloud_users.idcs_user_id  is 'IDCS user ID (filled automatically).';
comment on column cloud_users.oci_iam_user_id  is 'OCI user OCID (filled automatically).';


-- Cloud_Users_Last_Login
-- Contains the last successfull login time for cloud users.
create table cloud_users_last_login (
    identity_domain_name varchar2(64) not null, 
    user_email varchar2(128) not null, 
    last_login timestamp (3) not null, 
    constraint pk_cloud_users_last_login primary key (identity_domain_name, user_email) using index, 
    constraint fk_users_last_login foreign key (identity_domain_name, user_email) references cloud_users (identity_domain_name, email)
);


comment on table cloud_users_last_login  is 'Contains all the OCI compartments monitored for Automatic Shutdown.';

comment on column cloud_users_last_login.identity_domain_name  is 'Identity Domain of this user information.';
comment on column cloud_users_last_login.user_email  is 'Cloud user e-mail.';
comment on column cloud_users_last_login.last_login  is 'Last successfull login time.';

-- Group_User_Assoc
-- Contains the associations of Cloud Users and Cloud Groups. A Cloud User can belong to one or more groups.
-- /!\ at least one group is required to allow the user to be able to logon.
create table group_user_assoc (
	identity_domain_name varchar2(64) not null, 
	group_name varchar2(128) not null, 
	user_email varchar2(128) not null, 
	creation_date date not null, 
	constraint pk_group_user_assoc primary key (identity_domain_name, group_name, user_email) using index, 
	constraint fk_grp_usr_assoc_cloud_groups foreign key (identity_domain_name, group_name) references cloud_groups (identity_domain_name, name), 
	constraint fk_grp_usr_assoc_cloud_users foreign key (identity_domain_name, user_email) references cloud_users (identity_domain_name, email)
);

comment on table group_user_assoc  is 'Contains the associations of Cloud Users and Cloud Groups. A Cloud User can belong to one or more groups.';

comment on column group_user_assoc.identity_domain_name  is 'Identity Domain of this group and user association.';
comment on column group_user_assoc.group_name  is 'Group name of this group and user association.';
comment on column group_user_assoc.user_email  is 'User''s e-mail of this group and user association.';
comment on column group_user_assoc.creation_date  is 'Creation date of this group and user association.';


-- Entitled Services
-- Contains the list of entitled services to this Cloud Account.
create table entitled_services (
    identity_domain_name varchar2(64) not null,
    es_doc clob CONSTRAINT ensure_json CHECK (es_doc IS JSON),
    date_of_retrieval timestamp(9) default systimestamp not null,
    constraint PK_entitled_services primary key (identity_domain_name)
)
LOB(es_doc)
STORE AS SECUREFILE (
COMPRESS HIGH
CACHE
DEDUPLICATE
)
--FLASHBACK ARCHIVE fla_cci
;

comment on table entitled_services  is 'Contains the list of entitled services to this Cloud Account.';

comment on column entitled_services.identity_domain_name  is 'Identity Domain the entitled services belongs to.';
comment on column entitled_services.es_doc  is 'JSON document containing the entitled services.';
comment on column entitled_services.date_of_retrieval  is 'Denotes the time of retrieval from Oracle Cloud of these information.';


-- Service Daily Usage Costs
-- Contains the daily usage costs per Cloud Service for a given Identity Domain.
create table service_daily_usage_costs (
    identity_domain_name varchar2(64) not null,
    service_name varchar2(64) not null,
    day_of_usage_cost date not null,
    suc_doc clob CONSTRAINT ensure_json_suc CHECK (suc_doc IS JSON),
    date_of_retrieval timestamp(9) default systimestamp not null
)
LOB(suc_doc)
STORE AS SECUREFILE (
COMPRESS HIGH
CACHE
DEDUPLICATE
);

alter table service_daily_usage_costs add constraint PK_service_daily_usage_costs primary key (identity_domain_name, service_name, day_of_usage_cost);

comment on table service_daily_usage_costs  is 'Contains the daily usage costs per Cloud Service for a given Identity Domain.';

comment on column service_daily_usage_costs.identity_domain_name  is 'Identity Domain the cloud services usage refers to.';
comment on column service_daily_usage_costs.service_name  is 'Cloud Service name for these daily usage costs.';
comment on column service_daily_usage_costs.day_of_usage_cost  is 'Date for these costs details.';
comment on column service_daily_usage_costs.suc_doc  is 'JSON document containing the daily cloud service usage costs.';
comment on column service_daily_usage_costs.date_of_retrieval  is 'Denotes the time of retrieval from Oracle Cloud of these information.';

-- Service Daily Usages
-- Contains the daily usages per Cloud Service for a given Identity Domain (i.e. the Cloud Service Metrics).
create table service_daily_usages (
    identity_domain_name varchar2(64) not null,
    service_name varchar2(64) not null,
    day_of_usage date not null,
    su_doc clob CONSTRAINT ensure_json_su CHECK (su_doc IS JSON),
    date_of_retrieval timestamp(9) default systimestamp not null
)
LOB(su_doc)
STORE AS SECUREFILE (
COMPRESS HIGH
CACHE
DEDUPLICATE
);

alter table service_daily_usages add constraint PK_service_daily_usages primary key (identity_domain_name, service_name, day_of_usage);

comment on table service_daily_usages  is 'Contains the daily usages per Cloud Service for a given Identity Domain (i.e. the Cloud Service Metrics).';

comment on column service_daily_usages.identity_domain_name  is 'Identity Domain the cloud services usages refers to.';
comment on column service_daily_usages.service_name  is 'Cloud Service name for these daily usages.';
comment on column service_daily_usages.day_of_usage  is 'Date for these resource metric usages details.';
comment on column service_daily_usages.su_doc  is 'JSON document containing the daily cloud service usages.';
comment on column service_daily_usages.date_of_retrieval  is 'Denotes the time of retrieval from Oracle Cloud of these information.';


-- Service Quotas
-- Contains the quotas per Cloud Service information.
create table service_quotas (
    identity_domain_name varchar2(64) not null,
    service_name varchar2(64) not null,
    sq_doc clob CONSTRAINT ensure_json_sq CHECK (sq_doc IS JSON),
    date_of_retrieval timestamp(9) default systimestamp not null
)
LOB(sq_doc)
STORE AS SECUREFILE (
COMPRESS HIGH
CACHE
DEDUPLICATE
);

comment on table service_quotas  is 'Contains the quotas per Cloud Service information.';

comment on column service_quotas.identity_domain_name  is 'Identity Domain the cloud services quotas refers to.';
comment on column service_quotas.service_name  is 'Cloud Service name for these quotas.';
comment on column service_quotas.sq_doc  is 'JSON document containing the cloud service quotas.';
comment on column service_quotas.date_of_retrieval  is 'Denotes the time of retrieval from Oracle Cloud of these information.';


-- Service Resources
-- List the Resources for all Cloud Services (common to all cloud accounts and Identity Domains).
create table service_resources (
    service_name varchar2(64) not null primary key,
    sr_doc clob CONSTRAINT ensure_json_sr CHECK (sr_doc IS JSON),
    date_of_retrieval timestamp(9) default systimestamp not null
)
LOB(sr_doc)
STORE AS SECUREFILE (
COMPRESS HIGH
CACHE
DEDUPLICATE
);

comment on table service_resources  is 'List the Resources for all Cloud Services (common to all cloud accounts and Identity Domains).';

comment on column service_resources.service_name  is 'Cloud Service name for these resources.';
comment on column service_resources.sr_doc  is 'JSON document containing the cloud service resources.';
comment on column service_resources.date_of_retrieval  is 'Denotes the time of retrieval from Oracle Cloud of these information.';

-- Services Cost
-- Contains the list of prices per Cloud Services resource.
create table services_cost (
	service_name  varchar2(128) not null,
	resource_type varchar2(128) not null,
	resource_option varchar2(128),
	byol          char(1) not null,
	unit          varchar2(64) not null,
	period        varchar2(64) not null,
	currency      varchar2(3) not null,
	price_payg    number not null,
	price_mf      number not null
);

create unique index idx_services_cost on services_cost (service_name,resource_type,resource_option,byol);


comment on table services_cost  is 'Contains the list of prices per Cloud Services resource.';

comment on column services_cost.service_name  is 'Cloud Service name for this cost entry.';
comment on column services_cost.resource_type  is 'Resource type for this cost entry.';
comment on column services_cost.resource_option  is 'Resource Option for this cost entry (example: Enterprise version...).';
comment on column services_cost.byol  is 'If ''Y'', this is a Bring Your Own License cost.';
comment on column services_cost.unit  is 'Unit for this cost entry.';
comment on column services_cost.period  is 'Hour or Month.';
comment on column services_cost.currency  is 'Currency for this cost entry (example: EUR, USD...).';
comment on column services_cost.price_payg  is 'Cost entry in Pay As You Go model.';
comment on column services_cost.price_mf  is 'Cost entry in Monthly Flex model.';


create table cloud_balances (
    IDENTITY_DOMAIN_NAME VARCHAR2(64 BYTE) NOT NULL, 
    BALANCE NUMBER NOT NULL,
	DATE_OF_RETRIEVAL TIMESTAMP (9) DEFAULT systimestamp NOT NULL,
    constraint PK_cloud_balances Primary Key (IDENTITY_DOMAIN_NAME,DATE_OF_RETRIEVAL)
);

comment on table cloud_balances  is 'Contains all the balances of identity domains managed by the Cloud Center Interface.';

comment on column cloud_balances.IDENTITY_DOMAIN_NAME is 'Identity domain name.';
comment on column cloud_balances.BALANCE is 'The cloud credits balance for this tenant at this time.'; 
comment on column cloud_balances.date_of_retrieval is 'Denotes the time of retrieval from Oracle Cloud of these information.';
