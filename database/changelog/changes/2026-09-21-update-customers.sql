--liquibase formatted sql

--changeset demo.dba:20260924-01 labels:demo,application-change context:demo

ALTER TABLE customers ADD (dob VARCHAR2(30 CHAR));

--rollback ALTER TABLE customers DROP COLUMN dob;
