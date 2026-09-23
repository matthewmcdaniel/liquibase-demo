# Liquibase Autonomous Database CI/CD demo

This repository demonstrates a Git-based Liquibase release process for an Oracle Autonomous Database. Pull requests validate database changes; an approved immutable Git tag deploys them.

The root changelog is [database/changelog/db.changelog-master.yaml](database/changelog/db.changelog-master.yaml). It is the ordered manifest for all database changes.

## One-time setup

1. Create the GitHub Environment `autonomous-production` and require DBA approval.
2. Add these environment secrets:

   | Secret | Value |
   | --- | --- |
   | `ADB_WALLET_BASE64` | Base64-encoded Autonomous Database wallet ZIP |
   | `ADB_TNS_ALIAS` | Service alias from `tnsnames.ora` |
   | `ADB_USERNAME` | Deployment-schema user |
   | `ADB_PASSWORD` | Deployment-schema password |

3. Protect `db-release-*` tags so only authorized release managers can create them.
4. Ensure the GitHub runner can reach the database listener. Use a self-hosted runner for private-network databases.

Create the wallet secret locally; do not commit the wallet:

```bash
base64 -w 0 Wallet_<database>.zip
```

On macOS, use `base64 Wallet_<database>.zip | tr -d '\n'`.

## Add and release a database change

1. Create a branch and add a new SQL file under `database/changelog/changes/`. Do not modify a changeset that has already been deployed.

   ```sql
   --liquibase formatted sql

   --changeset demo.dba:20260923-02
   ALTER TABLE demo_orders ADD (priority_code VARCHAR2(10 CHAR));

   --rollback ALTER TABLE demo_orders DROP COLUMN priority_code;
   ```

2. Add the file to the end of `database/changelog/db.changelog-master.yaml`, after any objects it depends on.

   ```yaml
   - include:
       file: changes/2026-09-23-add-order-priority.sql
       relativeToChangelogFile: true
   ```

3. Open a pull request. The workflow runs `liquibase validate` and uploads an `update-sql` artifact for DBA review.
4. Merge the approved pull request to `main`. A branch push validates only; it never deploys.
5. Create and push the next immutable release tag from the approved commit:

   ```bash
   git tag -a db-release-1 -m "Initial demo release"
   git push origin db-release-1
   ```

6. Approve the `autonomous-production` deployment in GitHub Actions. The workflow validates, creates a pre-release database checkpoint, applies pending changes, and records the release checkpoint.

To promote an existing tag manually, run **Liquibase Autonomous Database CI/CD** from Actions and provide `release_tag`, for example `db-release-1`.

## Roll back a release

Always generate and review rollback SQL before executing it.

1. In Actions, open **Liquibase Autonomous Database Rollback** and select the release revision being rolled back.
2. Run with `mode: preview` and the checkpoint immediately before the release, for example `pre-db-release-2`.
3. Approve the environment and review the `liquibase-rollback-sql` artifact.
4. Run again with `mode: execute` and the same checkpoint, then approve the execution.

The workflow can roll back only changesets that have manual `--rollback` SQL. Checkpoints are recorded in the `TAG` column of `DATABASECHANGELOG`.

```sql
SELECT id, author, filename, tag, dateexecuted
FROM databasechangelog
ORDER BY orderexecuted;
```

## Local validation

With Liquibase installed:

```bash
liquibase validate --url='offline:oracle?version=26.0' \
  --changelog-file=database/changelog/db.changelog-master.yaml

liquibase update-sql --url='offline:oracle?version=26.0' \
  --changelog-file=database/changelog/db.changelog-master.yaml
```
