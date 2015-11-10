CREATE SCHEMA [mdq]
AUTHORIZATION [mds_schema_user]
GO
GRANT EXECUTE ON SCHEMA:: [mdq] TO [mds_exec]
GRANT REFERENCES ON SCHEMA:: [mdq] TO [mds_ssb_user]
GRANT SELECT ON SCHEMA:: [mdq] TO [mds_ssb_user]
GRANT INSERT ON SCHEMA:: [mdq] TO [mds_ssb_user]
GRANT DELETE ON SCHEMA:: [mdq] TO [mds_ssb_user]
GRANT UPDATE ON SCHEMA:: [mdq] TO [mds_ssb_user]
GRANT EXECUTE ON SCHEMA:: [mdq] TO [mds_ssb_user]
GO
