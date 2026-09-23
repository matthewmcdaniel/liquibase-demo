--liquibase formatted sql

--changeset demo.dba:20260922-01 labels:demo,application-change context:demo runOnChange:false
--validCheckSum: 9:89a5df3f8c4c7d2c040676c560e08fe4
ALTER TABLE demo_orders ADD (source_system VARCHAR2(30 CHAR));

--rollback ALTER TABLE demo_orders DROP COLUMN source_system;
