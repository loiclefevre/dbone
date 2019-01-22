set define off


create or replace PACKAGE ORACLE_CLOUD_IDENTITY_MANAGEMENT AS 

  /**
   * Launch the global refresh process.
   */
  procedure applyConfiguration( id_name in varchar2 );

END ORACLE_CLOUD_IDENTITY_MANAGEMENT;

/


create or replace PACKAGE BODY ORACLE_CLOUD_IDENTITY_MANAGEMENT AS

  g_DEBUG boolean := false;

  g_OCI_API_VERSION VARCHAR2(16):= '20160918';                 -- Oracle Cloud Infrastructure API version

  /**
   * Log a message related to an identity domain on the standard output and in the log_messages table.
   *
   * IN:
   * - id_name: identity domain
   * - msg: the message to log
   */
  procedure log( id_name in varchar2, msg in varchar2 ) as
    PRAGMA AUTONOMOUS_TRANSACTION;
  begin
    dbms_output.put_line( id_name || ': ' || msg );
    insert into log_messages (identity_domain, message) values (id_name, msg);
    commit;
  end log;

  procedure addHeader( p_i in number, p_name in varchar2, p_value in varchar2 ) as 
  begin
    if p_i = 1 then
      apex_web_service.g_request_headers.delete();
    end if;  

    apex_web_service.g_request_headers(p_i).name := p_name;
    apex_web_service.g_request_headers(p_i).value := p_value;
  end;

  function POST( p_REST_API_endpoint in varchar2, p_REST_API_body in varchar2, p_parse_response in boolean ) return CLOB as
    res CLOB;
  begin
    res := apex_web_service.make_rest_request( 
        p_url => p_REST_API_endpoint,
        p_http_method => 'POST',
        p_wallet_path => 'file:/home/oracle/wallet',
        p_body => p_REST_API_body
    );

    if g_DEBUG then
      dbms_output.put_line( 'POST response: ' || apex_web_service.g_status_code || ' (' || res || ') for (' || p_REST_API_endpoint || ' with '|| p_REST_API_body ||')' );
    end if;

    if p_parse_response then
      apex_json.parse(res);  
    end if;

    return res;
  end POST;

  function PATCH( p_REST_API_endpoint in varchar2, p_REST_API_body in varchar2, p_parse_response in boolean ) return CLOB as
    res CLOB;
  begin
    res := apex_web_service.make_rest_request( 
        p_url => p_REST_API_endpoint,
        p_http_method => 'PATCH',
        p_wallet_path => 'file:/home/oracle/wallet',
        p_body => p_REST_API_body
    );

    if g_DEBUG then
      dbms_output.put_line( 'PATCH response: ' || apex_web_service.g_status_code || ' (' || res || ') for (' || p_REST_API_endpoint || ' with '|| p_REST_API_body ||')' );
    end if;

    if p_parse_response then
      apex_json.parse(res);      
    end if;

    return res;
  end PATCH;

  function GET( p_REST_API_endpoint in varchar2, p_parse_response in boolean ) return CLOB as
    res CLOB;
  begin
    res := apex_web_service.make_rest_request( 
        p_url => p_REST_API_endpoint,
        p_http_method => 'GET',
        p_wallet_path => 'file:/home/oracle/wallet'
    );

    if g_DEBUG then
      dbms_output.put_line( 'GET response: ' || apex_web_service.g_status_code || ' (' || res || ') for (' || p_REST_API_endpoint || ')' );
    end if;

    if p_parse_response then
      apex_json.parse(res);
    end if;

    return res;
  end GET;

  -- https://idcs-40e2d2239516421bb71b0bb09597c4fa.identity.oraclecloud.com/oauth2/v1/
  function GetIDCSOAUTH2Token( idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2 ) return varchar2 as
    res CLOB;
  begin
    addHeader( 1, 'Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Basic '||replace(replace(replace(utl_encode.text_encode(client_id||':'||client_secret,'WE8ISO8859P1', UTL_ENCODE.BASE64),chr(9)),chr(10)),chr(13)) );

    res := POST( 'https://' || idcs_identifier || '.identity.oraclecloud.com/oauth2/v1/token', 'grant_type=client_credentials&scope=urn:opc:idm:__myscopes__', true);

    return apex_json.get_varchar2(p_path => 'access_token');
  end GetIDCSOAUTH2Token;

  procedure IDCSAssociateAllAdminRoleToGroup( id_name in varchar2, OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, group_id in varchar2, group_name in varchar2 ) as
    res CLOB;
    res2 CLOB;
    i number;
    j number;
    l_members_count number;
    l_totalResults number;
    l_role varchar2(256);
    l_associationFound char(1);
    k number;
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/AppRoles?attributes=members,adminRole,availableToGroups,displayName', true );

    i := 0;
    j := 0;
    l_totalResults := apex_json.get_number( p_path => 'totalResults' );

    loop
        if APEX_JSON.get_varchar2(p_path => 'Resources[%d].adminRole', p0 => (j+1)) = 'true' and 
           APEX_JSON.get_varchar2(p_path => 'Resources[%d].availableToGroups', p0 => (j+1)) = 'true' then
           l_associationFound := 'N';
           l_members_count := nvl(apex_json.get_count(p_path => 'Resources[%d].members', p0 => (j+1)),0);
           l_role := APEX_JSON.get_varchar2(p_path => 'Resources[%d].displayName', p0 => (j+1));
           --dbms_output.put_line(l_role||': '||l_members_count);
           k := 0;

           loop
             exit when k >= l_members_count;
               if APEX_JSON.get_varchar2(p_path => 'Resources[%d].members[%d].type', p0 => (j+1), p1 => (k+1)) = 'Group' and 
                  APEX_JSON.get_varchar2(p_path => 'Resources[%d].members[%d].value', p0 => (j+1), p1 => (k+1)) = group_id then
                  l_associationFound := 'Y';
               end if;
             k := k + 1;
           end loop;

           if l_associationFound = 'N' and l_role not in ('OCI_Administrator','CASB_Administrator','Audit Administrator','OMCEXTERNAL_ENTITLEMENT_ADMINISTRATOR',
                'ADWC_Administrator','EXADATAOCI_Administrator','Administrator','Identity Domain Administrator','Security Administrator','Application Administrator',
                'ATP_Administrator','User Administrator') then
                --dbms_output.put_line('association not found with ' || l_role );
                log(id_name,'Associating IDCS application role ' || l_role || ' to group ' || group_name);
                addHeader( 1, 'Content-Type', 'application/json; charset=UTF-8' );
                addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

                res2 := POST( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Grants', q'!{"grantee": {
                            "type": "Group",
                            "value": "!' || group_id || q'!"
                        },
                        "app": {
                            "value": "!' || APEX_JSON.get_varchar2(p_path => 'Resources[%d].app.value', p0 => (j+1)) || q'!"
                        },
                        "entitlement" : {
                            "attributeName": "appRoles",
                            "attributeValue": "!' || APEX_JSON.get_varchar2(p_path => 'Resources[%d].id', p0 => (j+1)) || q'!"
                        },
                        "grantMechanism" : "ADMINISTRATOR_TO_GROUP",
                        "schemas": [
                        "urn:ietf:params:scim:schemas:oracle:idcs:Grant"
                      ]}!', false ); 
           end if;
        end if;


        i := i + 1;
        exit when i > l_totalresults;

        j := mod(i,50);
        if j = 0 then
            addHeader( 1, 'Content-Type', 'application/json; charset=UTF-8' );
            addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

            res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/AppRoles?attributes=members,adminRole,availableToGroups,displayName&startIndex=' || (i+1), true );
        end if;
    end loop;

  end IDCSAssociateAllAdminRoleToGroup;

  procedure IDCSAssociateUserToGroupOCI_Administrator( id_name in varchar2, OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, user_id in varchar2, p_given_name in varchar2, p_family_name in varchar2 ) as
    res CLOB;
    l_user_name varchar2(256);
    l_members_count number;
    l_associationFound char(1);
    l_group_id varchar2(256);
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );
    res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups?attributes=members,displayName,urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group&filter=displayName+eq+%22OCI_Administrators%22', true );

    l_members_count := nvl(apex_json.get_count(p_path => 'Resources[1].members'),0);

    l_group_id := APEX_JSON.get_varchar2(p_path => 'Resources[1].id');

    l_user_name := p_given_name || '.' || p_family_name;

    l_associationFound := 'N';

    for i in 1..l_members_count loop
      if APEX_JSON.get_varchar2(p_path => 'Resources[1].members[%d].type', p0 => i) = 'User' and 
         APEX_JSON.get_varchar2(p_path => 'Resources[1].members[%d].name', p0 => i) = l_user_name then
              l_associationFound := 'Y';
      end if;
    end loop;

    if l_associationFound = 'N' then
        log(id_name,'Associating user '||l_user_name||' with OCI_Administrators...');
        addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
        addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

        res := PATCH( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups/'||l_group_id, 
                  q'!{"schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
                      "Operations": [
                        {
                          "op": "add",
                          "path": "members",
                          "value": [
                            {
                              "value": "!' || user_id || q'!",
                              "type": "User"
                            }
                          ]
                        }
                      ]
                    }!', false);

        -- dbms_output.put_line(res);
    end if;

  end IDCSAssociateUserToGroupOCI_Administrator;

  procedure IDCSAssociateGroupsToUser( id_name in varchar2, OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, user_id in varchar2, p_given_name in varchar2, p_family_name in varchar2 ) as
    res CLOB;
    l_user_name varchar2(256);
    l_members_count number;
    l_totalResults number;
    l_associationFound char(1);
    l_group_id varchar2(256);
  begin
    -- dbms_output.put_line('select tga.group_name, count(*) over () as nb from team_group_assoc tga, cloud_users cu where cu.team=tga.team_name and cu.country=tga.team_country and cu.given_name='''||given_name||''' and cu.family_name='''||family_name||''' and cu.enabled=''Y'' and tga.identity_domain_name='''||id_name||''';');

    for cur in (select gua.group_name from group_user_assoc gua, cloud_users cu
                where cu.email=gua.user_email and cu.given_name=p_given_name and cu.family_name=p_family_name and cu.enabled='Y' and gua.identity_domain_name=id_name and cu.identity_domain_name=id_name) loop
        dbms_output.put_line(cur.group_name||': '||p_given_name||'.'||p_family_name||' on '||id_name||' => https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups?attributes=members,displayName,urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group&filter=displayName+eq+%22' || cur.group_name || '%22');
        addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
        addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

        res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups?attributes=members,displayName,urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group&filter=displayName+eq+%22' || cur.group_name || '%22', true );
        -- dbms_output.put_line( res );

        -- totalResults must be equals to 1 since the group has already been created!
        l_members_count := nvl(apex_json.get_count(p_path => 'Resources[1].members'),0);

        l_group_id := APEX_JSON.get_varchar2(p_path => 'Resources[1].id');

        l_user_name := p_given_name || '.' || p_family_name;

        l_associationFound := 'N';

        for i in 1..l_members_count loop
          if APEX_JSON.get_varchar2(p_path => 'Resources[1].members[%d].type', p0 => i) = 'User' and 
             APEX_JSON.get_varchar2(p_path => 'Resources[1].members[%d].name', p0 => i) = l_user_name then
                  l_associationFound := 'Y';
          end if;
        end loop;

        if l_associationFound = 'N' then
            log(id_name,'Associating user '||l_user_name||' with '||cur.group_name||'...');
            addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
            addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

            res := PATCH( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups/'||l_group_id, 
                      q'!{"schemas": ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
                          "Operations": [
                            {
                              "op": "add",
                              "path": "members",
                              "value": [
                                {
                                  "value": "!' || user_id || q'!",
                                  "type": "User"
                                }
                              ]
                            }
                          ]
                        }!', false);

            -- dbms_output.put_line(res);
        end if;

    end loop;

  end IDCSAssociateGroupsToUser;

  procedure IDCSCreateGroup( OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, group_name in varchar2, group_description in varchar2, group_id out varchar2 ) as
    res CLOB;
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    res := POST( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups',
                  '{"displayName": "' || group_name || q'!",
                    "externalId": "42123456",
                    "urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group": {
                    "creationMechanism": "api",
                    "description": "!' || group_description || q'!"
                    },
                    "schemas": [
                       "urn:ietf:params:scim:schemas:core:2.0:Group",
                       "urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group"
                    ]
                   }!', true);

    group_id := APEX_JSON.get_varchar2(p_path => 'id');

  end IDCSCreateGroup;

  procedure IDCSCreateUser( OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, team in varchar2, country in varchar2, 
                            given_name in varchar2, family_name in varchar2, email in varchar2, administrator in varchar2, user_id out varchar2 ) as
    res CLOB;
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    res := POST( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Users',
                 q'!{"schemas": [
                        "urn:ietf:params:scim:schemas:core:2.0:User"
                      ],
                      "userName": "!' || given_name || '.' || family_name || q'!",
                      "name": {
                        "familyName": "!' || initcap(replace(family_name,'.',' ')) || q'!",
                        "givenName": "!' || initcap(replace(given_name,'.',' ')) || q'!"
                      },
                      "active": true,
                      "title": "Team !' || team || q'!",
                      "emails": [
                        {
                          "value": "!' || email || q'!",
                          "type": "work",
                          "primary": true
                        }
                      ]
                    }!', true);

    -- dbms_output.put_line( res );
    -- dbms_output.put_line( apex_web_service.g_status_code );

    user_id := APEX_JSON.get_varchar2(p_path => 'id');

  end IDCSCreateUser;

  function IDCSGroupExist( OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, group_name in varchar2, group_id out varchar2 ) return boolean as
    res CLOB;
    l_count number;
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Groups?attributes=members,displayName,urn:ietf:params:scim:schemas:oracle:idcs:extension:group:Group', true );

    l_count := apex_json.get_number( p_path => 'totalResults' );

    for i in 1..l_count loop
        if APEX_JSON.get_varchar2(p_path => 'Resources[%d].displayName', p0 => i) = group_name then 
        begin
            group_id := APEX_JSON.get_varchar2(p_path => 'Resources[%d].id', p0 => i);
            return true; 
        end;
        end if;
        -- dbms_output.put_line( 'Existing group: ' || APEX_JSON.get_varchar2(p_path => 'Resources[%d].displayName', p0 => i) ); 
    end loop;

    return false;

  end IDCSGroupExist;

  function IDCSUserExist( OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2, user_name in varchar2, user_id out varchar2 ) return boolean as
    res CLOB;
    l_count number;
  begin
    addHeader( 1, 'Content-Type', 'application/scim+json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    res := GET( 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/Users?filter=userName+eq+%22' || user_name || '%22', true );

    l_count := apex_json.get_number( p_path => 'totalResults' );

    if l_count = 1 then
        user_id := apex_json.get_varchar2( p_path => 'Resources[1].id' );
        -- dbms_output.put_line(user_id||' !!! '||l_count);
        return true;
    end if;

    return false;

  end IDCSUserExist;

  procedure OCICreateGroupMapping( id_name in varchar2, p_group_ocid in varchar2, p_group_name_idp in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'post';                              -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      l_oci_idp_ocid identity_domains.oci_idp_ocid%TYPE;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key, oci_idp_ocid 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key, l_oci_idp_ocid
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/identityProviders/' || l_oci_idp_ocid || '/groupMappings/';
      l_body := '{"idpGroupName":"' || p_group_name_idp || '", "groupId":"'||p_group_ocid||'"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, false );
      -- log(id_name,'Group mapping of ' || p_group_name_idp||': '||apex_web_service.g_status_code || '(' || res || ')');
  end OCICreateGroupMapping;

  procedure OCICreateGroupsMappings( id_name in varchar2 ) as 
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key

      l_oci_idp_ocid identity_domains.oci_idp_ocid%TYPE;
      l_group_name varchar2(256);
      l_group_to_federate char(1);
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key, oci_idp_ocid 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key, l_oci_idp_ocid
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/groups/';
      l_filter := 'compartmentId=' || l_tenant_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true );

      for i in 1..nvl(apex_json.get_count(p_path => '.'),0) loop
        l_group_name := APEX_JSON.get_varchar2(p_path => '[%d].name', p0 => i);
        select case count(*) when 1 then 'Y' else 'N' end  into l_group_to_federate from cloud_groups where identity_domain_name=id_name and name = l_group_name;  
        if l_group_to_federate='Y' then
            OCICreateGroupMapping( id_name, APEX_JSON.get_varchar2(p_path => '[%d].id', p0 => i), l_group_name );
        end if;
      end loop;

  end OCICreateGroupsMappings;

  procedure OCICreateGroup( id_name in varchar2, p_group_name in varchar2, p_description in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'post';                             -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);

  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/groups/';

      l_body := '{"compartmentId" : "' || l_tenant_ocid || '",
                  "description" : "'||p_description||'",
                  "name" : "'||p_group_name||'"
                }';

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;

      res := POST( l_url, l_body, false );
  end OCICreateGroup;

  procedure OCICreateGroupPolicyforCompartment( id_name in varchar2, p_group_name in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'post';                             -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);

      l_compartment_child_of cloud_groups.Compartment_child_of%TYPE;
      l_compartment_name varchar2(128);
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      select compartment_child_of 
      into l_compartment_child_of 
      from cloud_groups where identity_domain_name = id_name and name = p_group_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/policies/';

      l_compartment_name := replace(p_group_name,'Users','');

      l_body := '{"compartmentId" : "' || l_tenant_ocid || '",
                  "description" : "Policy to manage compartment '||l_compartment_name||'.",
                  "name" : "FR-'||l_compartment_name||'-Policy",
                  "statements":[
                    "Allow group '|| p_group_name ||' to manage all-resources in compartment '|| case when lower(l_compartment_child_of) = 'root' then '' else l_compartment_child_of || ':' end || l_compartment_name ||'",
                    "Allow group '|| p_group_name ||' to use virtual-network-family in compartment Networks",
                    "Allow group '|| p_group_name ||' to inspect tag-namespaces in tenancy",
                    "Allow group '|| p_group_name ||'  to use repos in tenancy"
                  ]}';

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;

      log(id_name,'Creating policy for OCI group ' || p_group_name || ' for compartment...');
      res := POST( l_url, l_body, false );


  end OCICreateGroupPolicyforCompartment;




  procedure OCICreateGroupIfNotExist( id_name in varchar2, p_group_name in varchar2, p_description in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key

      l_group_found boolean;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/groups/';
      l_filter := 'compartmentId=' || l_tenant_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true );

      l_group_found := false;

      for i in 1..nvl(apex_json.get_count(p_path => '.'),0) loop
        if APEX_JSON.get_varchar2(p_path => '[%d].name', p0 => i) = p_group_name then
            l_group_found := true;
        end if;
      end loop;

      if not l_group_found then
        log(id_name,'OCI group ' || p_group_name || ' needs to be created in OCI IAM...');
        OCICreateGroup( id_name, p_group_name, p_description );
        OCICreateGroupPolicyforCompartment( id_name, p_group_name );
      end if;

  end OCICreateGroupIfNotExist;


  /**
   * Resynchronize groups as defined in the database and those defined inside IDCS or OCI IAM.
   * 
   * OCI_Administrators <-> Administrators
   * SandboxUsers <-> SandboxUsers
   */
  procedure resynchGroups( id_name in varchar2 ) as
    idcs_identifier identity_domains.idcs_identifier%TYPE;
    client_id identity_domains.client_id%TYPE;
    client_secret identity_domains.client_secret%TYPE;
    OAUTH2Token varchar2(32767);
    group_id varchar2(128);
  begin
    select idcs_identifier, client_id, client_secret into idcs_identifier, client_id, client_secret from identity_domains where name = id_name;

    for cur in (select c.type, c.name, c.description, c.admin_role from cloud_groups c where identity_domain_name=id_name)
    loop
        log(id_name,'Synchronizing '||cur.type||' group...'); 
        -- dbms_output.put_line('Resynch group ' || cur.type||', '||cur.name||', '||cur.admin_role );
        if cur.type = 'IDCS' then
            oauth2token := GetIDCSOAUTH2Token(idcs_identifier, client_id, client_secret);
            --dbms_output.put_line('OAUTH2 token: ' || oauth2token);
            if not IDCSGroupExist(oauth2token, idcs_identifier, client_id, client_secret, cur.name, group_id) then
                log(id_name,'IDCS group ' || cur.name || ' doesn''t exist! Need to create it...');
                IDCSCreateGroup(oauth2token, idcs_identifier, client_id, client_secret, cur.name, cur.description, group_id);
            else
                log(id_name,'IDCS group ' || cur.name || ' already exists! Just need to synchronize the associated roles.');
            end if;

            if lower(cur.admin_role) = 'true' then
                IDCSAssociateAllAdminRoleToGroup( id_name, OAUTH2Token, idcs_identifier, client_id, client_secret, group_id, cur.name );
            end if;

            OCICreateGroupIfNotExist( id_name, cur.name, cur.description );

        end if;

    end loop;

    -- Create the Groups Mappings with OCI IAM if they doesn't exist
    OCICreateGroupsMappings( id_name );

  end resynchGroups;

  function OCIExistAPIKeyforUser( id_name in varchar2, p_user_ocid in varchar2, p_key_fingerprint in varchar2) return boolean as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/users/'||p_user_ocid||'/apiKeys';

      apex_web_service.g_request_headers(3).name := 'Authorization';
      apex_web_service.g_request_headers(3).value := signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true );

      for i in 1..nvl(apex_json.get_count(p_path => '.'),0) loop
        if APEX_JSON.get_varchar2(p_path => '[%d].fingerprint', p0 => i) = p_key_fingerprint then
            return true;
        end if;
      end loop;

      return false;

  end OCIExistAPIKeyforUser;

  procedure OCIUploadAPIKeyforUser(id_name in varchar2, p_user_ocid in varchar2, p_public_key_pem in varchar2) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'post';                              -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/users/'||p_user_ocid||'/apiKeys';
      l_body := '{"key":"' || replace( p_public_key_pem, chr(10), '\n') || '"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, false );
  end OCIUploadAPIKeyforUser;

  procedure IDCSUpdateLastLogins( id_name in varchar2, OAUTH2Token in varchar2, idcs_identifier in varchar2, client_id in varchar2, client_secret in varchar2 ) as
    res CLOB;
    l_start_date varchar2(10);
    l_end_date varchar2(10);
    l_url varchar2(10000);
    l_totalResults number;

    l_user_name varchar2(256);
    l_user_email varchar2(128);
    l_timestamp varchar2(64);
  begin
    select to_char(trunc(current_date - 15,'DD'),'YYYY-MM-DD'), to_char(trunc(current_date + 30,'DD'),'YYYY-MM-DD') into l_start_date, l_end_date from dual;

    addHeader( 1, 'Content-Type', 'application/json; charset=UTF-8' );
    addHeader( 2, 'Authorization', 'Bearer '||oauth2token );

    l_url := 'https://' || idcs_identifier || '.identity.oraclecloud.com/admin/v1/AuditEvents?filter=eventId eq "sso.session.create.success" and timestamp gt "' || l_start_date || 'T00:00:00.001Z" and timestamp lt "' || l_end_date || 'T00:00:00.001Z" and ssoIdentityProviderType eq "LOCAL"&attributes=actorName,ssoIdentityProviderType,ssoIdentityProvider,clientIp,timestamp,message&sortBy=actorName&sortOrder=ascending';
    l_url := replace( l_url, '"', '%22' );
    l_url := replace( l_url, ' ', '%20' );

    res := GET( l_url, true );

    -- dbms_output.put_line( res );

    l_totalResults := nvl(apex_json.get_number( p_path => 'totalResults' ), 0 );

    for i in 1..l_totalResults
    loop
        l_user_name := APEX_JSON.get_varchar2(p_path => 'Resources[%d].actorName', p0 => i); 
        if instr(l_user_name,'@') = 0 then
            l_timestamp := APEX_JSON.get_varchar2(p_path => 'Resources[%d].timestamp', p0 => i);
            select email into l_user_email from cloud_users where given_name || '.' || family_name = l_user_name and identity_domain_name=id_name;

            begin
              insert into cloud_users_last_login values (id_name, l_user_email, to_timestamp(l_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"'));
            exception when others then 
              update cloud_users_last_login set last_login = to_timestamp(l_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"') where identity_domain_name = id_name and user_email = l_user_email;
            end;
            commit;

        end if;

    end loop;

  end IDCSUpdateLastLogins;

  procedure OCIUploadAPIKeyToUsers( id_name in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key

      l_default_key_fingerprint identity_domains.default_key_fingerprint%TYPE;
      l_default_public_key_pem identity_domains.default_public_key_pem%TYPE;

      l_users_count number;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key, default_key_fingerprint, default_public_key_pem 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key, l_default_key_fingerprint, l_default_public_key_pem 
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'identity.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_API_VERSION || '/users';

      l_users_filter := 'compartmentId=' || replace(l_tenant_ocid,':','%3A') || '&' || 'limit=50';

      apex_web_service.g_request_headers(3).name := 'Authorization';
      apex_web_service.g_request_headers(3).value := signGetRequest( l_date_header, l_service_uri || '?' || l_users_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_users_filter;    

      res := GET( l_url, true );

      l_users_count := nvl(apex_json.get_count(p_path => '.'),0);

      -- dbms_output.put_line('users: ' || l_users_count );

      for i in 1..l_users_count loop
        update cloud_users cu set cu.oci_iam_user_id = APEX_JSON.get_varchar2(p_path => '[%d].id', p0 => i) 
        where 'oracleidentitycloudservice/' || cu.given_name || '.' || cu.family_name = APEX_JSON.get_varchar2(p_path => '[%d].name', p0 => i)
        and cu.enabled='Y';
      end loop;

    commit;

    for cur in (select distinct cu.given_name, cu.family_name, cu.oci_iam_user_id 
                from group_user_assoc gua, cloud_users cu 
                where cu.email=gua.user_email and cu.enabled='Y' and cu.administrator='N' and gua.identity_domain_name=id_name)
    loop
        if not OCIExistAPIKeyforUser( id_name, cur.oci_iam_user_id, l_default_key_fingerprint ) then
            log(id_name,'Uploading default API key for user '||cur.given_name || '.' || cur.family_name||'...');
            OCIUploadAPIKeyforUser( id_name, cur.oci_iam_user_id, l_default_public_key_pem );
        /*else
            log(id_name,'Default API key for user '||cur.given_name || '.' || cur.family_name||' already uploaded.'); */
        end if;
    end loop;

  end OCIUploadAPIKeyToUsers;

  /**
   * Resynchronize users as defined in the database and those defined inside IDCS or OCI IAM.
   * 
   * OCI_Administrators <-> Administrators
   */
  procedure resynchUsers( id_name in varchar2 ) as
    idcs_identifier identity_domains.idcs_identifier%TYPE;
    client_id identity_domains.client_id%TYPE;
    client_secret identity_domains.client_secret%TYPE;
    OAUTH2Token varchar2(32767);
    user_id varchar2(128);
  begin
    select idcs_identifier, client_id, client_secret into idcs_identifier, client_id, client_secret from identity_domains where name = id_name;

    oauth2token := GetIDCSOAUTH2Token(idcs_identifier, client_id, client_secret);

    for cur in (select distinct cu.team, cu.country, cu.given_name, cu.family_name, cu.email, cu.administrator 
                from group_user_assoc gua, cloud_users cu 
                where cu.email=gua.user_email and cu.enabled='Y' and gua.identity_domain_name=id_name and cu.identity_domain_name=id_name)
    loop
        log(id_name,'Synchronizing '||cur.given_name || '.' || cur.family_name||' user...'); 
        --oauth2token := GetIDCSOAUTH2Token(idcs_identifier, client_id, client_secret);
        --dbms_output.put_line('OAUTH2 token: ' || oauth2token);
        if not IDCSUserExist(oauth2token, idcs_identifier, client_id, client_secret, cur.given_name || '.' || cur.family_name, user_id) then
            log(id_name,'IDCS user ' || cur.given_name || '.' || cur.family_name || ' doesn''t exist! Need to create it...');
            IDCSCreateUser(oauth2token, idcs_identifier, client_id, client_secret, cur.team, cur.country, cur.given_name, cur.family_name, cur.email, 'N', user_id);
        else
            log(id_name,'IDCS user ' || cur.given_name || '.' || cur.family_name || ' already exists! Just need to synchronize the associated roles.');
        end if;

        update cloud_users cu set cu.idcs_user_id = user_id where cu.email=cur.email and cu.identity_domain_name=id_name;

        -- the Mapping with OCI IAM is done through Group having OCI-V2- application role (which brings SSO federation)
        --dbms_output.put_line('Associating user '||cur.given_name||'('||user_id||') with group...');
        -- TODO: optimization, create a PL/SQL table collection to store all users and request (REST APIs) group members once per group!
        IDCSAssociateGroupsToUser( id_name, OAUTH2Token, idcs_identifier, client_id, client_secret, user_id, cur.given_name, cur.family_name );

        if cur.administrator = 'Y' then
          IDCSAssociateUserToGroupOCI_Administrator( id_name, OAUTH2Token, idcs_identifier, client_id, client_secret, user_id, cur.given_name, cur.family_name );
        end if;

    end loop;

    commit;

    -- Upload API Key for OCI user!
    OCIUploadAPIKeyToUsers( id_name );

    IDCSUpdateLastLogins( id_name, oauth2token, idcs_identifier, client_id, client_secret );
  end resynchUsers;

  procedure applyConfiguration( id_name in varchar2 ) as
  begin
    log(id_name,'Applying Identity configuration');
    resynchGroups( id_name );
    resynchUsers( id_name );
  end applyConfiguration;

END ORACLE_CLOUD_IDENTITY_MANAGEMENT;

/
