CREATE USER [mds_schema_user] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[mdm]
GO
GRANT CREATE PROCEDURE TO [mds_schema_user]
GRANT CREATE TABLE TO [mds_schema_user]
GRANT CREATE VIEW TO [mds_schema_user]
GRANT DELETE TO [mds_schema_user]
GRANT INSERT TO [mds_schema_user]
GRANT REFERENCES TO [mds_schema_user]
GRANT SELECT TO [mds_schema_user]
GRANT UPDATE TO [mds_schema_user]
