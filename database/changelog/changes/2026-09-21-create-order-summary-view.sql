--liquibase formatted sql

--changeset demo.dba:20260921-04 labels:demo,reporting context:demo runOnChange:false
--comment Depends on DEMO_CUSTOMERS and DEMO_ORDERS; included last so referenced objects exist.
CREATE OR REPLACE VIEW demo_customer_order_summary AS
SELECT c.customer_id,
       c.customer_name,
       COUNT(o.order_id) AS order_count,
       NVL(SUM(o.order_total), 0) AS order_total
  FROM demo_customers c
  LEFT JOIN demo_orders o ON o.customer_id = c.customer_id
 GROUP BY c.customer_id, c.customer_name;

--rollback DROP VIEW demo_customer_order_summary;
