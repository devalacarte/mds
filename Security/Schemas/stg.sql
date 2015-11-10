CREATE SCHEMA [stg]
AUTHORIZATION [mds_schema_user]
GO
GRANT EXECUTE ON SCHEMA:: [stg] TO [mds_exec]
GRANT REFERENCES ON SCHEMA:: [stg] TO [mds_ssb_user]
GRANT SELECT ON SCHEMA:: [stg] TO [mds_ssb_user]
GRANT INSERT ON SCHEMA:: [stg] TO [mds_ssb_user]
GRANT DELETE ON SCHEMA:: [stg] TO [mds_ssb_user]
GRANT UPDATE ON SCHEMA:: [stg] TO [mds_ssb_user]
GRANT EXECUTE ON SCHEMA:: [stg] TO [mds_ssb_user]
GO
