--liquibase formatted sql

--changeset demo.dba:20260923-01 labels:demo,application-change context:demo
--preconditions onFail:MARK_RAN onError:HALT
--precondition-sql-check expectedResult:0 SELECT COUNT(*) FROM user_tab_columns WHERE table_name = 'DEMO_ORDERS' AND column_name = 'SOURCE_SYSTEM_2'
ALTER TABLE demo_orders ADD (source_system_2 VARCHAR2(30 CHAR));

--rollback ALTER TABLE demo_orders DROP COLUMN source_system_2;
