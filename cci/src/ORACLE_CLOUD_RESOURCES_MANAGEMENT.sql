create or replace PACKAGE ORACLE_CLOUD_RESOURCES_MANAGEMENT AS 

  /**
   * Automatically shuts down VM or BM instances which don't have the 'Mandatory_Tags:Schedule' tag set to '24x7'.
   * 
   * IN:
   * - id_name: identity domain name
   */
  procedure AutomaticShutdown( id_name in varchar2 );

  /**
   * Automatically starts up VM, BM instances, VM Based Db Systems, ADWC and ATPC instances which have the 'Mandatory_Tags:Schedule' tag set to 'OfficeHours'.
   * 
   * IN:
   * - id_name: identity domain name
   */
  procedure AutomaticStartup( id_name in varchar2 );

  /**
   * Returns the list of billed resources for a given compartment (currency is Euro).
   *
   * IN:
   * - id_name: identity domain name
   * - p_user_name: 
   */
  function QueryBilledResources( id_name in varchar2, p_user_name in varchar2, p_password in varchar2, p_compartment_ocid in varchar2 ) return CLOB;

END ORACLE_CLOUD_RESOURCES_MANAGEMENT;

/

create or replace PACKAGE BODY ORACLE_CLOUD_RESOURCES_MANAGEMENT AS
  
  g_DEBUG boolean := false; -- global debug flag

  g_OCI_QUERY_API_VERSION VARCHAR2(16)          := '20180409';    -- Oracle Cloud Infrastructure Query API version
  g_OCI_DBSYSTEM_API_VERSION VARCHAR2(16)       := '20160918';    -- Oracle Cloud Infrastructure Db System API version
  g_OCI_INSTANCE_API_VERSION VARCHAR2(16)       := '20160918';    -- Oracle Cloud Infrastructure Instance API version
  g_OCI_OBJECT_STORAGE_API_VERSION VARCHAR2(16) := '20160918';    -- Oracle Cloud Infrastructure Object Storage API version
  
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

  /**
   * Add an header to an HTTP/S request using APEX_JSON.
   *
   * IN:
   * - p_i: parameter position
   * - p_name: parameter name
   * - p_value: parameter value
   */
  procedure addHeader( p_i in number, p_name in varchar2, p_value in varchar2 ) as 
  begin
    if p_i = 1 then
      apex_web_service.g_request_headers.delete();
    end if;  

    apex_web_service.g_request_headers(p_i).name := p_name;
    apex_web_service.g_request_headers(p_i).value := p_value;
  end addHeader;

  /**
   * Invoke a POST HTTP/S request using APEX_JSON. Optionnaly parses the response for further computation.
   * 
   * IN:
   * - p_REST_API_endpoint: REST API end point or URL
   * - p_REST_API_body: REST API body
   * - p_parse_response: boolean to tell to parse or not the response
   *
   * RETURN:
   * - the response as a CLOB
   */
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
  
  /**
   * Invoke a POST HTTP/S request using APEX_JSON. Optionnaly parses the response for further computation. 
   * This function also manages properly the APEX_JSON context for interleaved calls and parses of JSON.
   * 
   * IN:
   * - p_REST_API_endpoint: REST API end point or URL
   * - p_REST_API_body: REST API body
   * - p_parse_response: boolean to tell to parse or not the response
   * 
   * OUT:
   * - p_parser_ctx: the APEX_JSON context to avoid JSON parsing clashes in case of interleaved APEX_JSON parsing
   *
   * RETURN:
   * - the response as a CLOB
   */
  function POST( p_REST_API_endpoint in varchar2, p_REST_API_body in varchar2, p_parse_response in boolean, p_parser_ctx out apex_json.t_values ) return CLOB as
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
      apex_json.parse( p_values => p_parser_ctx, p_source => res);  
    end if;

    return res;
  end POST;

  /**
   * Invoke a PATCH HTTP/S request using APEX_JSON. Optionnaly parses the response for further computation.
   * 
   * IN:
   * - p_REST_API_endpoint: REST API end point or URL
   * - p_REST_API_body: REST API body
   * - p_parse_response: boolean to tell to parse or not the response
   *
   * RETURN:
   * - the response as a CLOB
   */
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

  /**
   * Invoke a GET HTTP/S request using APEX_JSON. Optionnaly parses the response for further computation.
   * 
   * IN:
   * - p_REST_API_endpoint: REST API end point or URL
   * - p_parse_response: boolean to tell to parse or not the response
   *
   * RETURN:
   * - the response as a CLOB
   */
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

  /**
   * Invoke a GET HTTP/S request using APEX_JSON. Optionnaly parses the response for further computation.
   * 
   * IN:
   * - p_REST_API_endpoint: REST API end point or URL
   * - p_parse_response: boolean to tell to parse or not the response
   *
   * OUT:
   * - p_parser_ctx: the APEX_JSON context to avoid JSON parsing clashes in case of interleaved APEX_JSON parsing
   *
   * RETURN:
   * - the response as a CLOB
   */
  function GET( p_REST_API_endpoint in varchar2, p_parse_response in boolean, p_parser_ctx out apex_json.t_values ) return CLOB as
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
      apex_json.parse( p_values => p_parser_ctx, p_source => res);
    end if;

    return res;
  end GET;

  /**
   * Returns the number of Db System in Running lifecycle state in a given compartment.
   *
   * IN:
   * - id_name: the identity domain name
   * - p_compartment_ocid: the compartment OCID
   * - p_identifier: the Db System OCID
   *
   * RETURN:
   * - the number of Db System in Running lifecycle state in a given compartment.
   */
  function getNumberOfRunningDbSystemDbNode( id_name in varchar2, p_compartment_ocid in varchar2, p_identifier in varchar2 ) return NUMBER as
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
      
      l_lifecycleState varchar2(64);
      l_number_of_nodes number;
      i number;

      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbNodes';
      l_filter := 'compartmentId=' || l_tenant_ocid || '&dbSystemId=' || p_identifier;      


      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_number_of_nodes := 0;
  
      -- log(id_name,'DbNode: ' || APEX_JSON.get_varchar2(p_path => '[1].lifecycleState') || ' - ' || res );
      
      i := 1;
      loop
        l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].lifecycleState', p0 => i);
        if l_lifecycleState = 'AVAILABLE' then
            i := i + 1;
            l_number_of_nodes := l_number_of_nodes + 1;
        elsif l_lifecycleState = 'STOPPED' then
            i := i + 1;
        else
            exit;
        end if;
      end loop;

      return l_number_of_nodes;      
  end;


  function getDbSystemCost( id_name in varchar2, p_compartment_ocid in varchar2, p_identifier in varchar2, l_comment out varchar2  ) return number as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_cpuCoreCount number;
      l_dataStorageSizeInGBs number;
      l_recoStorageSizeInGB number;
      l_databaseEdition varchar2(128);
      l_licenseModel varchar2(128);
      l_diskRedundancy varchar2(128);
      l_nodeCount number;
      
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      l_running_nodes := getNumberOfRunningDbSystemDbNode(id_name, p_compartment_ocid, p_identifier); 

      log(id_name,'DbNode: running nodes = '  || l_running_nodes );

      if l_running_nodes = 0 then
        return 0;
      end if;
  
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbSystems/' || p_identifier;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
  
      
      l_cpuCoreCount := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'cpuCoreCount');
      l_dataStorageSizeInGBs := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'dataStorageSizeInGBs');
      l_recoStorageSizeInGB := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'recoStorageSizeInGB');
      l_nodeCount := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'nodeCount');
      
      l_databaseEdition := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'databaseEdition');
      l_licenseModel := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'licenseModel');
      l_diskRedundancy := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'diskRedundancy');
  
      log(id_name, res);
  

      select nvl(l_running_nodes * sum(resource_cost_per_second),0) into l_cost from (
        select s.*, case when resource_type='CPU' then l_cpuCoreCount * price_payg / 3600
                    when resource_type='Block Storage' then (l_dataStorageSizeInGBs + l_recoStorageSizeInGB + 200) * price_payg / decode(lower(period),'month',744,1) / 3600
        end as resource_cost_per_second
        from services_cost s where byol=decode('BRING_YOUR_OWN_LICENSE','BRING_YOUR_OWN_LICENSE','Y','N') and currency='EUR' and service_name='DbSystem'
      );
       
      return l_cost;
  end;

  function getAutonomousDataWarehouseCost( id_name in varchar2, p_compartment_ocid in varchar2, p_identifier in varchar2, l_comment out varchar2 ) return number as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_cpuCoreCount number;
      l_dataStorageSizeInTBs number;
      l_licenseModel varchar2(128);
      l_nodeCount number;
      l_lifecycleState varchar2(64);
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDataWarehouses/' || p_identifier;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');
      l_cpuCoreCount := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'cpuCoreCount');
      l_dataStorageSizeInTBs := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'dataStorageSizeInTBs');
      l_licenseModel := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'licenseModel');

      log(id_name, 'DbNode: ' || l_lifecycleState || ': ' || res);
  
      l_comment := 'lifecycleState=' || l_lifecycleState || ', cpuCoreCount=' || l_cpuCoreCount || ', dataStorageSizeInTBs=' || l_dataStorageSizeInTBs || ', licenseModel=' || l_licenseModel;

      if l_lifecycleState = 'TERMINATED' then
        return 0;
      end if;

      select nvl(sum(resource_cost_per_second),0) into l_cost from (
        select s.*, case when resource_type='CPU' then decode(l_lifecycleState,'STOPPED',0,l_cpuCoreCount * price_payg / 3600)
                    when resource_type='Storage' then l_dataStorageSizeInTBs * price_payg / decode(lower(period),'month',744,1) / 3600
        end as resource_cost_per_second
        from services_cost s where byol=decode('BRING_YOUR_OWN_LICENSE','BRING_YOUR_OWN_LICENSE','Y','N') and currency='EUR' and service_name='AutonomousDataWarehouse'
      );
       
      return l_cost;
  end;

  function getBoolVolumeSize( id_name in varchar2, p_instanceId in varchar2, p_availabilityDomain in varchar2, p_compartmentId in varchar2 ) return number as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      l_filter VARCHAR2(256);                                         -- URI filter
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      i number;
      l_boot_volume_id varchar2(128);
      l_boot_volume_size number;
      
      l_parser_ctx apex_json.t_values;
      l_parser_ctx_boot_volume apex_json.t_values; 
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'iaas.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_INSTANCE_API_VERSION || '/bootVolumeAttachments/';
      l_filter := 'availabilityDomain=' || p_availabilityDomain || '&compartmentId=' || p_compartmentId || '&=instanceId' || p_instanceId; 

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true, l_parser_ctx );
      
      -- log(id_name, 'Test:' ||resBootVolume);
      
      i := 1;
      l_boot_volume_size := 0;
      loop   
        l_boot_volume_id :=  APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].bootVolumeId', p0 => i);
        exit when l_boot_volume_id is null;
        
      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'iaas.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_INSTANCE_API_VERSION || '/bootVolumes/' || l_boot_volume_id;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx_boot_volume );

       l_boot_volume_size := l_boot_volume_size + APEX_JSON.get_varchar2(p_values => l_parser_ctx_boot_volume, p_path => 'sizeInGBs');
       

       log(id_name, 'Test2:' || res );        
        
        i := i + 1;
      end loop;
      
      return l_boot_volume_size;
  end;

  function getInstanceCost( id_name in varchar2, p_identifier in varchar2, l_comment out varchar2 ) return number as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_shape varchar2(64);
      l_storageSizeInGBs number;
      l_lifecycleState varchar2(64);
      l_availabilityDomain varchar2(128);
      l_compartmentId varchar2(128);
      l_instanceId varchar2(128);
      
      l_cost number;
      l_boot_volume_cost number;
      l_boot_volume_size number;
      
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'iaas.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_INSTANCE_API_VERSION || '/instances/' || p_identifier;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_shape := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'shape');
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');
      l_availabilityDomain := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'availabilityDomain');
      l_compartmentId := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'compartmentId');
      l_instanceId := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'Id');
      
    
      l_comment := 'lifecycleState=' || l_lifecycleState || ', shape=' || l_shape;

      l_boot_volume_size := getBoolVolumeSize( id_name, l_instanceId, l_availabilityDomain, l_compartmentId );


      select nvl(sum(resource_cost_per_second),0) into l_boot_volume_cost from (
        select s.*, l_boot_volume_size * price_payg / decode(lower(period),'month',744,1) / 3600 as resource_cost_per_second
        from services_cost s where currency='EUR' and service_name='Instance' and resource_type='Block Storage'
      );

      if l_lifecycleState != 'STOPPED' then 
          select nvl(sum(resource_cost_per_second),0) into l_cost from (
            select s.*, price_payg / 3600 as resource_cost_per_second
            from services_cost s where currency='EUR' and service_name='Instance' and resource_type='CPU' and resource_option=l_shape
          );
      else
        l_cost := 0;
      end if;

      return l_cost + l_boot_volume_cost;
  end;

  function getBucketCost( id_name in varchar2, p_identifier in varchar2 ) return number as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_storageSizeInGBs number;
      
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'objectstorage.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_OBJECT_STORAGE_API_VERSION || '/instances/' || p_identifier;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      /*l_shape := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'shape');
  

      select nvl(sum(resource_cost_per_second),0) into l_cost from (
        select s.*, price_payg / 3600 as resource_cost_per_second
        from services_cost s where currency='EUR' and service_name='Instance' and resource_type='CPU' and resource_option=l_shape
      );
*/
      return l_cost;
  end;

  /**
   * Returns the list of billed resources for a given compartment (currency is Euro).
   *
   * IN:
   * - id_name: identity domain name
   * - p_user_name: 
   */
  function QueryBilledResources( id_name in varchar2, p_user_name in varchar2, p_password in varchar2, p_compartment_ocid in varchar2 ) return CLOB as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      l_items_count number;
      l_resource_type varchar2(128);
      l_identifier varchar2(256);
      l_display_name varchar2(256);
      
      json_response CLOB;
      
      l_parser_ctx apex_json.t_values;
      
      l_comment varchar2(4000);
  begin
    log(id_name,'Querying resources information for user ' || p_user_name || '...' );
    -- list all resources without any filter:
    -- https://docs.cloud.oracle.com/iaas/api/#/en/search/0.0.4/ResourceSummaryCollection/
    -- https://docs.cloud.oracle.com/iaas/api/#/en/search/0.0.4/datatypes/StructuredSearchDetails
    -- https://docs.cloud.oracle.com/iaas/api/#/en/search/0.0.4/ResourceSummaryCollection/SearchResources
    
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'query.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_QUERY_API_VERSION || '/resources';
-- (lifecycleState=''Running'' || lifecycleState=''Available'' || lifecycleState=''Active'') &&
-- TODO: add , Bucket 
      l_body := '{"type": "Structured","query": "query AutonomousDataWarehouse, DbSystem, Instance, Volume resources where  compartmentId = ''' || p_compartment_ocid || ''' sorted by timeCreated desc"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, true, l_parser_ctx );

      log(id_name,res);

      l_items_count := nvl(apex_json.get_count(p_values => l_parser_ctx, p_path => 'items'),0);
      
      dbms_lob.CREATETEMPORARY( json_response, true, dbms_lob.SESSION );
      dbms_lob.append(json_response,'{"itemsCount": ');
      dbms_lob.append(json_response,to_char(l_items_count));
      dbms_lob.append(json_response,',' || chr(10));
      dbms_lob.append(json_response,' "items": [' || chr(10));
        
      for i in 1..l_items_count loop
        -- have to reparse because of following API CALL using APEX_JSON and modifying its context!
        l_resource_type := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].resourceType', p0 => i);
        l_identifier    := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].identifier', p0 => i);
        l_display_name  := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].displayName', p0 => i);

        -- DbSystem
        if l_resource_type = 'DbSystem' then
          if i > 1 then dbms_lob.append(json_response,',' || chr(10)); end if;
          dbms_lob.append(json_response,'  {"resourceType": "' || l_resource_type || '", "displayName": "' || l_display_name || '", "costPerSecond": ' || trim(to_char(getDbSystemCost(id_name, p_compartment_ocid, l_identifier, l_comment),'0.9999999999')) || ', "currency": "EUR"}' );
        -- Instance
        elsif l_resource_type = 'Instance' then
          if i > 1 then dbms_lob.append(json_response,',' || chr(10)); end if;
          dbms_lob.append(json_response,'  {"resourceType": "' || l_resource_type || '", "displayName": "' || l_display_name || '", "costPerSecond": ' || trim(to_char(getInstanceCost(id_name, l_identifier,l_comment),'0.9999999999')) || ', "currency": "EUR", "comment": "'||l_comment||'"}' );
        -- AutonomousDataWarehouse
        elsif l_resource_type = 'AutonomousDataWarehouse' then
          if i > 1 then dbms_lob.append(json_response,',' || chr(10)); end if;
          dbms_lob.append(json_response,'  {"resourceType": "' || l_resource_type || '", "displayName": "' || l_display_name || '", "costPerSecond": ' || trim(to_char(getAutonomousDataWarehouseCost(id_name, p_compartment_ocid, l_identifier, l_comment),'0.9999999999')) || ', "currency": "EUR", "comment": "'||l_comment||'"}' );
--        elsif l_resource_type = 'Bucket' then
--          if i > 1 then dbms_lob.append(json_response,',' || chr(10)); end if;
--          dbms_lob.append(json_response,'  {"resourceType": "' || l_resource_type || '", "displayName": "' || l_display_name || '", "costPerSecond": ' || trim(to_char(getBucketCost(id_name, l_identifier),'0.9999999999')) || ', "currency": "EUR"}' );
        else
          if i > 1 then dbms_lob.append(json_response,',' || chr(10)); end if;
          dbms_lob.append(json_response,'  {"resourceType": "' || l_resource_type || '", "displayName": "' || l_display_name || '", "costPerSecond": ' || '1234.56' || ', "currency": "EUR"}' );
        end if;
      end loop;

      dbms_lob.append(json_response,chr(10) || ' ]' || chr(10));
      dbms_lob.append(json_response,'}');

      return json_response;
  end QueryBilledResources;

  /**
   * Stops a DbSystem Db Node VM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM instance name
   * - p_ocid: instance OCID
   */
  procedure stopDbNode( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
  begin
      log(id_name,'Automatic Shutdown, stopping db system db node ' || p_instance_name || '...' );

      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbNodes/' || p_ocid;
      l_filter := 'action=STOP';
      
      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, '{}', l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( '{}' ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := POST( l_url, '{}', false );
      
      -- log(id_name, res);
  end stopDbNode;

  procedure stopAllRunningDbSystemDbNodes( id_name in varchar2, p_compartment_ocid in varchar2, p_identifier in varchar2 ) as
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
      
      l_lifecycleState varchar2(64);
      l_number_of_nodes number;
      l_hostname varchar2(256);
      l_dbnode_id varchar2(256);
      i number;

      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbNodes';
      l_filter := 'compartmentId=' || l_tenant_ocid || '&dbSystemId=' || p_identifier;      

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_number_of_nodes := 0;
  
      log(id_name,'DbNode: ' || res );

      i := 1;
      loop
        l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].lifecycleState', p0 => i);
        l_hostname := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].hostname', p0 => i);
        l_dbnode_id := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].id', p0 => i);
        if l_lifecycleState = 'AVAILABLE' then
            i := i + 1;
            stopDbNode( id_name, l_hostname, l_dbnode_id ); 
        elsif l_lifecycleState = 'STOPPED' then
            i := i + 1;
            log(id_name,'Automatic Shutdown, db system db node ' || l_hostname || ' already stopped, nothing to do.' );
        else
            exit;
        end if;
      end loop;
   end stopAllRunningDbSystemDbNodes;

  /**
   * Manages the stop of a DbSystem VM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM instance name
   * - p_ocid: instance OCID
   */
  procedure manageStopDbSystem( id_name in varchar2, p_compartment_ocid in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_shape varchar2(64);
      l_cpuCoreCount number;
      l_dataStorageSizeInGBs number;
      l_recoStorageSizeInGB number;
      l_databaseEdition varchar2(128);
      l_licenseModel varchar2(128);
      l_diskRedundancy varchar2(128);
      l_nodeCount number;
      
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbSystems/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );

      l_shape := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'shape');
      l_nodeCount := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'nodeCount');

      dbms_output.put_line(res);

      if l_shape like 'VM%' then
            log(id_name,'Automatic Shutdown, stopping db system (' || l_nodeCount || ' db node(s)) ' || p_instance_name || ', since it is a VM shape...' );
            stopAllRunningDbSystemDbNodes(id_name,p_compartment_ocid,p_ocid);
      else
            log(id_name,'Automatic Shutdown, not stopping db system ' || p_instance_name || ', since it is a Bare Metal shape!' );
      end if;
      
  end manageStopDbSystem;

  /**
   * Stops a VM or BM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM or BM instance name
   * - p_ocid: instance OCID
   */
  procedure stopInstance( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
  begin
      log(id_name,'Automatic Shutdown, stopping instance ' || p_instance_name || '...' );
  
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'iaas.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_INSTANCE_API_VERSION || '/instances/' || p_ocid;
      l_filter := 'action=STOP';
      
      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, ' ', l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( ' ' ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := POST( l_url, ' ', false );
      
      --log(id_name, res);
  end stopInstance;


  procedure stopAutonomousDataWarehouse( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      
      l_cpuCoreCount number;
      l_dataStorageSizeInTBs number;
      l_licenseModel varchar2(128);
      l_nodeCount number;
      l_lifecycleState varchar2(64);
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDataWarehouses/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');

      if l_lifecycleState = 'AVAILABLE' then
          log(id_name,'Automatic Shutdown, stopping autonomous data warehouse ' || p_instance_name || '...' );

          l_method := 'post';
        
          --Build request Headers
          select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
          addHeader( 1, 'date', l_date_header );
          l_host_header := 'database.' || l_region || '.oraclecloud.com';
          addHeader( 2, 'host', l_host_header );
    
          l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDataWarehouses/' || p_ocid || '/actions/stop';
    
          l_body := '{}';

          addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
          addHeader( 4, 'content-type', 'application/json' );
          addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );
    
          l_url := 'https://' || l_host_header || l_service_uri;    
    
          res := POST( l_url, l_body, true, l_parser_ctx );
      
      end if;
  end stopAutonomousDataWarehouse;

  procedure stopAutonomousTransactionProcessing( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      
      l_cpuCoreCount number;
      l_dataStorageSizeInTBs number;
      l_licenseModel varchar2(128);
      l_nodeCount number;
      l_lifecycleState varchar2(64);
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDatabases/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');

      if l_lifecycleState = 'AVAILABLE' then
          log(id_name,'Automatic Shutdown, stopping autonomous transaction processing ' || p_instance_name || '...' );

          l_method := 'post';
        
          --Build request Headers
          select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
          addHeader( 1, 'date', l_date_header );
          l_host_header := 'database.' || l_region || '.oraclecloud.com';
          addHeader( 2, 'host', l_host_header );
    
          l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDatabases/' || p_ocid || '/actions/stop';
    
          l_body := '{}';

          addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
          addHeader( 4, 'content-type', 'application/json' );
          addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );
    
          l_url := 'https://' || l_host_header || l_service_uri;    
    
          res := POST( l_url, l_body, true, l_parser_ctx );
      
      end if;
  end stopAutonomousTransactionProcessing;

  /**
   * Automatically shuts down VM or BM instances in a given compartment which don't have the 'Mandatory_Tags:Schedule' tag set to '24x7'.
   * It also recursively looks for nested compartments' VM and BM instances.
   * 
   * IN:
   * - id_name: identity domain name
   * - p_compatment_name: compartment name
   * - p_compartment_ocid: compartment ocid
   */
  procedure AutomaticShutdownInCompartment( id_name in varchar2, p_compartment_name in varchar2, p_compartment_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      l_items_count number;
      l_resource_type varchar2(128);
      l_identifier varchar2(256);
      l_display_name varchar2(256);
      l_lifecycleState varchar2(256);
      
      json_response CLOB;
      
      l_parser_ctx apex_json.t_values;
  begin
      log(id_name,'Automatic Shutdown, analyzing compartment ' || p_compartment_name || '...' );
    
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'query.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_QUERY_API_VERSION || '/resources';
--      l_body := '{"type": "Structured","query": "query AutonomousDataWarehouse, AutonomousTransactionProcessing, Instance, DbSystem resources where compartmentId = ''' || p_compartment_ocid || ''' && (lifecycleState=''Running'' || lifecycleState=''Available'' || lifecycleState=''Active'') && (definedTags.namespace != ''Mandatory_Tags'' || definedTags.key != ''Schedule'' || definedTags.value != ''24x7'') sorted by timeCreated asc"}'; 
      l_body := '{"type": "Structured","query": "query AutonomousDataWarehouse, AutonomousTransactionProcessing, Instance, DbSystem resources where compartmentId = ''' || p_compartment_ocid || ''' && (definedTags.namespace != ''Mandatory_Tags'' || definedTags.key != ''Schedule'' || definedTags.value != ''24x7'') sorted by timeCreated asc"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, true, l_parser_ctx );

      --log(id_name,res);

      l_items_count := nvl(apex_json.get_count(p_values => l_parser_ctx, p_path => 'items'),0);
      
      for i in 1..l_items_count loop 
        l_resource_type  := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].resourceType', p0 => i);
        l_identifier     := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].identifier', p0 => i);
        l_display_name   := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].displayName', p0 => i);
        l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].lifecycleState', p0 => i);
        
        if g_debug = true then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to shutdown...');
        end if;

        if l_resource_type = 'DbSystem' and l_lifecycleState = 'AVAILABLE' then
          -- https://docs.cloud.oracle.com/iaas/api/#/en/database/20160918/DbNode/DbNodeAction
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to shutdown...');
          manageStopDbSystem(id_name, p_compartment_ocid, l_display_name, l_identifier);
        elsif l_resource_type = 'Instance' and l_lifecycleState = 'Running' then
          -- https://docs.cloud.oracle.com/iaas/api/#/en/iaas/20160918/Instance/InstanceAction
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to shutdown...');
          stopInstance(id_name, l_display_name, l_identifier);
        elsif l_resource_type = 'AutonomousDataWarehouse' then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to shutdown...');
          stopAutonomousDataWarehouse(id_name, l_display_name, l_identifier);
        elsif l_resource_type = 'AutonomousTransactionProcessing' then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to shutdown...');
          stopAutonomousTransactionProcessing(id_name, l_display_name, l_identifier);
        end if;

    end loop;

      -- Recursive for sub-compartments...    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'query.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_QUERY_API_VERSION || '/resources';

      l_body := '{"type": "Structured","query": "query Compartment resources where compartmentId = ''' || p_compartment_ocid || ''' sorted by timeCreated asc"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, true, l_parser_ctx );

      --log(id_name,res);

      l_items_count := nvl(apex_json.get_count(p_values => l_parser_ctx, p_path => 'items'),0);
      
      for i in 1..l_items_count loop
        l_identifier    := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].identifier', p0 => i);
        l_display_name  := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].displayName', p0 => i);


        AutomaticShutdownInCompartment( id_name, l_display_name, l_identifier );

      end loop;
  end AutomaticShutdownInCompartment;

  /**
   * Automatically shuts down VM, BM instances, VM Based Db Systems, ADWC and ATPC which don't have the 'Mandatory_Tags:Schedule' tag set to '24x7'.
   * 
   * IN:
   * - id_name: identity domain name
   */
  procedure AutomaticShutdown( id_name in varchar2 ) as
  begin
    log(id_name,'Automatic Instance Shutdown Starting...' );
    
    for resources in (select compartment_ocid, compartment_name from automatic_shutdown_compartment where identity_domain_name=id_name)
    loop
      AutomaticShutdownInCompartment( id_name, resources.compartment_name, resources.compartment_ocid );
    end loop;
  end AutomaticShutdown;


  /**
   * Starts a DbSystem Db Node VM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM instance name
   * - p_ocid: instance OCID
   */
  procedure startDbNode( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
  begin
      log(id_name,'Automatic Startup, starting db system db node ' || p_instance_name || '...' );

      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbNodes/' || p_ocid;
      l_filter := 'action=START';
      
      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, '{}', l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( '{}' ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := POST( l_url, '{}', false );
      
      -- log(id_name, res);
  end startDbNode;

  procedure startAllRunningDbSystemDbNodes( id_name in varchar2, p_compartment_ocid in varchar2, p_identifier in varchar2 ) as
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
      
      l_lifecycleState varchar2(64);
      l_number_of_nodes number;
      l_hostname varchar2(256);
      l_dbnode_id varchar2(256);
      i number;

      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbNodes';
      l_filter := 'compartmentId=' || l_tenant_ocid || '&dbSystemId=' || p_identifier;      

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_number_of_nodes := 0;
  
      log(id_name,'DbNode: ' || res );

      i := 1;
      loop
        l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].lifecycleState', p0 => i);
        l_hostname := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].hostname', p0 => i);
        l_dbnode_id := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => '[%d].id', p0 => i);
        if l_lifecycleState = 'STOPPED' then
            i := i + 1;
            startDbNode( id_name, l_hostname, l_dbnode_id ); 
        elsif l_lifecycleState = 'AVAILABLE' then
            i := i + 1;
            log(id_name,'Automatic Startup, db system db node ' || l_hostname || ' already started, nothing to do.' );
        else
            exit;
        end if;
      end loop;
   end startAllRunningDbSystemDbNodes;

  /**
   * Manages the start of a DbSystem VM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM instance name
   * - p_ocid: instance OCID
   */
  procedure manageStartDbSystem( id_name in varchar2, p_compartment_ocid in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      
      l_shape varchar2(64);
      l_cpuCoreCount number;
      l_dataStorageSizeInGBs number;
      l_recoStorageSizeInGB number;
      l_databaseEdition varchar2(128);
      l_licenseModel varchar2(128);
      l_diskRedundancy varchar2(128);
      l_nodeCount number;
      
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/dbSystems/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );

      l_shape := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'shape');
      l_nodeCount := APEX_JSON.get_number(p_values => l_parser_ctx, p_path => 'nodeCount');

      dbms_output.put_line(res);

      if l_shape like 'VM%' then
            log(id_name,'Automatic Startup, starting db system (' || l_nodeCount || ' db node(s)) ' || p_instance_name || ', since it is a VM shape...' );
            startAllRunningDbSystemDbNodes(id_name,p_compartment_ocid,p_ocid);
      else
            log(id_name,'Automatic Startup, not starting db system ' || p_instance_name || ', since it is a Bare Metal shape!' );
      end if;
      
  end manageStartDbSystem;

  /**
   * Starts a VM or BM instance by calling the appropriate REST API.
   *
   * IN:
   * - id_name: identity name
   * - p_instance_name: VM or BM instance name
   * - p_ocid: instance OCID
   */
  procedure startInstance( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_filter varchar2(512);                                      -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
  begin
      log(id_name,'Automatic Shutdown, stopping instance ' || p_instance_name || '...' );
  
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'iaas.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_INSTANCE_API_VERSION || '/instances/' || p_ocid;
      l_filter := 'action=START';
      
      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri || '?' || l_filter, l_host_header, ' ', l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( ' ' ) );

      l_url := 'https://' || l_host_header || l_service_uri || '?' || l_filter;    

      res := POST( l_url, ' ', false );
      
      --log(id_name, res);
  end startInstance;


  procedure startAutonomousDataWarehouse( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      
      l_cpuCoreCount number;
      l_dataStorageSizeInTBs number;
      l_licenseModel varchar2(128);
      l_nodeCount number;
      l_lifecycleState varchar2(64);
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDataWarehouses/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');

      if l_lifecycleState != 'AVAILABLE' then
          log(id_name,'Automatic Startup, starting autonomous data warehouse ' || p_instance_name || '...' );

          l_method := 'post';
        
          --Build request Headers
          select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
          addHeader( 1, 'date', l_date_header );
          l_host_header := 'database.' || l_region || '.oraclecloud.com';
          addHeader( 2, 'host', l_host_header );
    
          l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDataWarehouses/' || p_ocid || '/actions/start';
    
          l_body := '{}';

          addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
          addHeader( 4, 'content-type', 'application/json' );
          addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );
    
          l_url := 'https://' || l_host_header || l_service_uri;    
    
          res := POST( l_url, l_body, true, l_parser_ctx );
      
      end if;
  end startAutonomousDataWarehouse;

  procedure startAutonomousTransactionProcessing( id_name in varchar2, p_instance_name in varchar2, p_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_method varchar2(16) := 'get';                              -- HTTP GET method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      
      l_cpuCoreCount number;
      l_dataStorageSizeInTBs number;
      l_licenseModel varchar2(128);
      l_nodeCount number;
      l_lifecycleState varchar2(64);
      l_running_nodes number;
      l_cost number;
      l_parser_ctx apex_json.t_values;
  begin
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key
      from identity_domains where name = id_name;

      --Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'database.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDatabases/' || p_ocid;

      addHeader( 3, 'Authorization', signGetRequest( l_date_header, l_service_uri, l_host_header, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := GET( l_url, true, l_parser_ctx );
  
      l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'lifecycleState');

      if l_lifecycleState != 'AVAILABLE' then
          log(id_name,'Automatic Startup, starting autonomous transaction processing ' || p_instance_name || '...' );

          l_method := 'post';
        
          --Build request Headers
          select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
          addHeader( 1, 'date', l_date_header );
          l_host_header := 'database.' || l_region || '.oraclecloud.com';
          addHeader( 2, 'host', l_host_header );
    
          l_service_uri := '/' || g_OCI_DBSYSTEM_API_VERSION || '/autonomousDatabases/' || p_ocid || '/actions/start';
    
          l_body := '{}';

          addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
          addHeader( 4, 'content-type', 'application/json' );
          addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );
    
          l_url := 'https://' || l_host_header || l_service_uri;    
    
          res := POST( l_url, l_body, true, l_parser_ctx );
      
      end if;
  end startAutonomousTransactionProcessing;

  /**
   * Automatically starts up VM, BM instances, VM Based Db Systems, ADWC and ATPC instances in a given compartment which 
   * have the 'Mandatory_Tags:Schedule' tag set to 'OfficeHours'.
   * It also recursively looks for nested compartments' VM, BM instances, VM Based Db Systems, ADWC and ATPC instances.
   * 
   * IN:
   * - id_name: identity domain name
   * - p_compatment_name: compartment name
   * - p_compartment_ocid: compartment ocid
   */
  procedure AutomaticStartupInCompartment( id_name in varchar2, p_compartment_name in varchar2, p_compartment_ocid in varchar2 ) as
      l_url VARCHAR2(512);                                         -- REST API endpoint URL
      res CLOB;                                                    -- JSON Response (i.e. the list of users)
      l_date_header varchar2(128);                                 -- Properly formatted HTTP date header
      l_host_header varchar2(128);                                 -- Properly formatted HTTP host header
      l_service_uri varchar2(512);                                 -- REST API endpoint URI
      l_users_filter varchar2(512);                                -- Filter used in the request
      l_method varchar2(16) := 'post';                             -- HTTP POST method     
      l_tenant_ocid identity_domains.tenant_ocid%TYPE;             -- Column containing the Identity Domain Tenant OCID
      l_region identity_domains.region%TYPE;                       -- Column containing the Identity Domain Region (us-ashburn-1 etc...)
      l_administrator_ocid identity_domains.administrator_ocid%TYPE;      -- Column containing the Administrator OCID
      l_administrator_key_fingerprint identity_domains.administrator_key_fingerprint%TYPE;     -- Column containing the Administrator key fingerprint
      l_administrator_private_key identity_domains.administrator_private_key%TYPE;             -- Column containing the Administrator private key
      l_body varchar2(32000);
      l_items_count number;
      l_resource_type varchar2(128);
      l_identifier varchar2(256);
      l_display_name varchar2(256);
      l_lifecycleState varchar2(256);
      
      json_response CLOB;
      
      l_parser_ctx apex_json.t_values;
  begin
      log(id_name,'Automatic Startup, analyzing compartment ' || p_compartment_name || '...' );
    
      -- Gather all required data
      select tenant_ocid, region, administrator_ocid, administrator_key_fingerprint, administrator_private_key 
      into l_tenant_ocid, l_region, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key 
      from identity_domains where name = id_name;
    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'query.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_QUERY_API_VERSION || '/resources';
--      l_body := '{"type": "Structured","query": "query AutonomousDataWarehouse, AutonomousTransactionProcessing, Instance, DbSystem resources where compartmentId = ''' || p_compartment_ocid || ''' && (lifecycleState=''Running'' || lifecycleState=''Available'' || lifecycleState=''Active'') && (definedTags.namespace != ''Mandatory_Tags'' || definedTags.key != ''Schedule'' || definedTags.value != ''24x7'') sorted by timeCreated asc"}'; 
      l_body := '{"type": "Structured","query": "query AutonomousDataWarehouse, AutonomousTransactionProcessing, Instance, DbSystem resources where compartmentId = ''' || p_compartment_ocid || ''' && (definedTags.namespace = ''Mandatory_Tags'' && definedTags.key = ''Schedule'' && definedTags.value = ''OfficeHours'') sorted by timeCreated asc"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, true, l_parser_ctx );

      --log(id_name,res);

      l_items_count := nvl(apex_json.get_count(p_values => l_parser_ctx, p_path => 'items'),0);
      
      for i in 1..l_items_count loop 
        l_resource_type  := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].resourceType', p0 => i);
        l_identifier     := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].identifier', p0 => i);
        l_display_name   := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].displayName', p0 => i);
        l_lifecycleState := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].lifecycleState', p0 => i);
        
        if g_debug = true then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to startup...');
        end if;

        if l_resource_type = 'DbSystem' and l_lifecycleState != 'AVAILABLE' then
          -- https://docs.cloud.oracle.com/iaas/api/#/en/database/20160918/DbNode/DbNodeAction
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to startup...');
          manageStartDbSystem(id_name, p_compartment_ocid, l_display_name, l_identifier);
        elsif l_resource_type = 'Instance' and l_lifecycleState != 'Running' then
          -- https://docs.cloud.oracle.com/iaas/api/#/en/iaas/20160918/Instance/InstanceAction
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to startup...');
          startInstance(id_name, l_display_name, l_identifier);
        elsif l_resource_type = 'AutonomousDataWarehouse' then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to startup...');
          startAutonomousDataWarehouse(id_name, l_display_name, l_identifier);
        elsif l_resource_type = 'AutonomousTransactionProcessing' then
          dbms_output.put_line('In compartment ' || p_compartment_name || ' resource ' || l_resource_type || ' ' || l_display_name|| ' ('||l_lifecycleState||') to startup...');
          startAutonomousTransactionProcessing(id_name, l_display_name, l_identifier);
        end if;

    end loop;

      -- Recursive for sub-compartments...    
      -- Build request Headers
      select to_char(CAST ( current_timestamp at time zone 'GMT' as timestamp with time zone),'Dy, DD Mon YYYY HH24:MI:SS TZR','NLS_DATE_LANGUAGE=''AMERICAN''') into l_date_header from dual;
      addHeader( 1, 'date', l_date_header );
      l_host_header := 'query.' || l_region || '.oraclecloud.com';
      addHeader( 2, 'host', l_host_header );

      l_service_uri := '/' || g_OCI_QUERY_API_VERSION || '/resources';

      l_body := '{"type": "Structured","query": "query Compartment resources where compartmentId = ''' || p_compartment_ocid || ''' sorted by timeCreated asc"}'; 

      addHeader( 3, 'Authorization', signPostRequest( l_date_header, l_service_uri, l_host_header, l_body, l_tenant_ocid, l_administrator_ocid, l_administrator_key_fingerprint, l_administrator_private_key ) );
      addHeader( 4, 'content-type', 'application/json' );
      addHeader( 5, 'x-content-sha256', calculateSHA256( l_body ) );

      l_url := 'https://' || l_host_header || l_service_uri;    

      res := POST( l_url, l_body, true, l_parser_ctx );

      --log(id_name,res);

      l_items_count := nvl(apex_json.get_count(p_values => l_parser_ctx, p_path => 'items'),0);
      
      for i in 1..l_items_count loop
        l_identifier    := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].identifier', p0 => i);
        l_display_name  := APEX_JSON.get_varchar2(p_values => l_parser_ctx, p_path => 'items[%d].displayName', p0 => i);


        AutomaticShutdownInCompartment( id_name, l_display_name, l_identifier );

      end loop;
  end AutomaticStartupInCompartment;

  /**
   * Automatically starts up VM, BM instances, VM Based Db Systems, ADWC and ATPC instances which have the 'Mandatory_Tags:Schedule' tag set to 'OfficeHours'.
   * 
   * IN:
   * - id_name: identity domain name
   */
  procedure AutomaticStartup( id_name in varchar2 ) as
  begin
    log(id_name,'Automatic Instance Startup Starting...' );
    
    for resources in (select compartment_ocid, compartment_name from automatic_shutdown_compartment where identity_domain_name=id_name)
    loop
      AutomaticStartupInCompartment( id_name, resources.compartment_name, resources.compartment_ocid );
    end loop;
  end AutomaticStartup;

END ORACLE_CLOUD_RESOURCES_MANAGEMENT;

/
