CREATE SCHEMA [mdm]
AUTHORIZATION [mds_schema_user]
GO
GRANT SELECT ON SCHEMA:: [mdm] TO [mds_email_user]
GRANT EXECUTE ON SCHEMA:: [mdm] TO [mds_exec]
GRANT REFERENCES ON SCHEMA:: [mdm] TO [mds_ssb_user]
GRANT SELECT ON SCHEMA:: [mdm] TO [mds_ssb_user]
GRANT INSERT ON SCHEMA:: [mdm] TO [mds_ssb_user]
GRANT DELETE ON SCHEMA:: [mdm] TO [mds_ssb_user]
GRANT UPDATE ON SCHEMA:: [mdm] TO [mds_ssb_user]
GRANT EXECUTE ON SCHEMA:: [mdm] TO [mds_ssb_user]
GO
