-- "Linking" Java procedures with PL/SQL functions:

create or replace FUNCTION OCIRESTAPIHelper_About RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.about () return java.lang.String';

/

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

create or replace FUNCTION calculateSHA256( p_body in varchar2 ) RETURN Varchar2
AS
LANGUAGE JAVA NAME 'OCIRESTAPIHelper.calculateSHA256 (java.lang.String) return java.lang.String';

/
