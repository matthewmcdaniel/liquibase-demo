--liquibase formatted sql

--changeset demo.dba:20260924-02 labels:demo,application-change context:demo
ALTER TABLE demo_orders ADD (priority_code VARCHAR2(10 CHAR));

--rollback ALTER TABLE demo_orders DROP COLUMN priority_code;
