# Liquibase Autonomous Database CI/CD demo

This repository demonstrates a DBA-owned database delivery flow. A DBA commits an immutable, formatted SQL changeset; Liquibase tracks it in `DATABASECHANGELOG`; GitHub Actions validates pull requests and deploys an approved, tagged release to an Oracle Autonomous Database.

The example deliberately uses schema objects, constraints, and a view rather than business data. The release manifest is [database/changelog/db.changelog-master.yaml](database/changelog/db.changelog-master.yaml). Its explicit include order captures the dependency chain:

`DEMO_CUSTOMERS` → `DEMO_CUSTOMER_ADDRESSES` and `DEMO_ORDERS` → `DEMO_CUSTOMER_ORDER_SUMMARY`.

## How the pipeline works

1. A pull request containing a new file in `database/changelog/changes/` runs `liquibase validate` and publishes an Oracle `update-sql` preview artifact.
2. A release branch such as `release/2026.09` may be used to stabilize and approve a release. Pushes to `main` and `release/**` validate only; they never deploy.
3. When the release is approved, create the next immutable numeric tag, such as `db-release-1`, at the reviewed commit. That tag runs the deploy job against the changelog exactly as it existed at that commit.
4. Environment protection rules (recommended: required DBA approver) approve the deployment. The workflow restores the wallet from a secret, checks pending changes, then runs `liquibase update`.
5. Liquibase records executed changesets, making a rerun safe: already-deployed changes are not run again.

The Actions **Run workflow** button is a deliberate promotion option: enter the name of an existing `db-release-<number>` tag. It will not deploy a branch, arbitrary commit, or individual SQL file.

## One-time GitHub setup

Create a GitHub Environment named `autonomous-production` and protect it with the DBA approver(s). Add these **environment secrets**:

| Secret | Value |
| --- | --- |
| `ADB_WALLET_BASE64` | Base64 of the complete Autonomous Database wallet ZIP |
| `ADB_TNS_ALIAS` | A service alias from `tnsnames.ora`, for example `mydb_high` |
| `ADB_USERNAME` | Deployment schema user (not `ADMIN` in a production setup) |
| `ADB_PASSWORD` | Deployment schema password |

Also protect `db-release-*` tags with a GitHub ruleset, allowing only the release manager or DBA team to create or update them. The recommended release sequence is: PR review → merge to `main` or a protected `release/*` branch → create the next `db-release-<number>` tag at the approved commit → approve the `autonomous-production` environment. This separates code review, release selection, and production authorization.

On Linux/macOS, prepare the wallet secret without placing it in the repository:

```bash
base64 -w 0 Wallet_QD0FKLUEW0XJU3U7.zip
```

macOS `base64` does not support `-w`; use `base64 Wallet_QD0FKLUEW0XJU3U7.zip | tr -d '\n'` instead. The included `.gitignore` prevents wallet archives and runtime material from being committed.

The GitHub-hosted runner must be able to reach the Autonomous Database listener. For a database with restricted network access, use a self-hosted runner with controlled egress in the approved network and replace `runs-on: ubuntu-latest` in the deploy job with its labels.

## Demo walkthrough

Use this sequence for a live presentation. The initial tag deploys the four sample objects in this repository; the second release demonstrates a typical DBA change.

1. **Show the release manifest.** Open [db.changelog-master.yaml](database/changelog/db.changelog-master.yaml) and explain that it is the ordered dependency graph. Then open `2026-09-21-create-orders.sql` to show a Git-tracked, formatted SQL changeset and its rollback statement.

2. **Deploy the baseline.** Create and push an annotated tag from the reviewed commit:

   ```bash
   git tag -a db-release-1 -m "Baseline Liquibase demo release"
   git push origin db-release-1
   ```

   GitHub Actions validates the tag, then pauses at the `autonomous-production` environment. A DBA approves that environment deployment. The job applies the master changelog in dependency order.

3. **Propose a DBA change in Git.** Create a working branch and add a new immutable changeset such as `database/changelog/changes/2026-09-22-add-order-source.sql`:

   ```sql
   --liquibase formatted sql
   --changeset demo.dba:20260922-01 labels:demo context:demo
   ALTER TABLE demo_orders ADD (source_system VARCHAR2(30 CHAR));
   --rollback ALTER TABLE demo_orders DROP COLUMN source_system;
   ```

   Add that file to `db.changelog-master.yaml` after `2026-09-21-create-orders.sql`; it depends on `DEMO_ORDERS`.

4. **Review the pull request.** Push the branch and open a PR. The `Validate and preview release` job runs `liquibase validate` and uploads the `liquibase-update-sql` artifact. Download the artifact and use it as the DBA’s proposed-production-SQL review.

5. **Select the production release.** Merge the reviewed PR to `main`, or merge it to a protected branch such as `release/2026.09`. Neither action deploys. Create a new immutable tag at the exact reviewed commit:

   ```bash
   git tag -a db-release-2 -m "Add order source column"
   git push origin db-release-2
   ```

6. **Approve and verify.** The tag-triggered workflow pauses for the `autonomous-production` approval. Approve it as the DBA, then inspect the successful `status` and `update` job output. Finally, connect with SQL Developer or SQLcl as the deployment schema and verify Liquibase’s audit trail:

   ```sql
   SELECT id, author, filename, dateexecuted
     FROM databasechangelog
    ORDER BY dateexecuted;

   SELECT column_name
     FROM user_tab_columns
    WHERE table_name = 'DEMO_ORDERS'
    ORDER BY column_id;
   ```

The important narrative is that no DBA runs the SQL by hand: Git identifies the reviewed release, the environment approval authorizes it, and Liquibase executes and audits it exactly once.

## Controlled rollback

Each deployment creates a `pre-db-release-<number>` checkpoint before applying changes and marks the resulting database state with the corresponding `db-release-<number>` tag. To undo a later release, roll back to the preceding release tag; for example, rolling back to `db-release-2` reverses every changeset deployed after that checkpoint. For the first checkpointed deployment, use its automatically created `pre-db-release-<number>` tag.

Use the **Liquibase Autonomous Database Rollback** workflow from the Actions page:

1. Run it with `mode: preview` and `rollback_tag: db-release-2` (or `pre-db-release-3` to undo the first checkpointed deployment).
2. Approve the protected `autonomous-production` environment and download the `liquibase-rollback-sql` artifact.
3. Have the DBA review the generated SQL, including data-loss implications.
4. Run it again with `mode: execute` and the same checkpoint. The preview job runs again, then the execution job requires its own environment approval before it calls `liquibase rollback`.

The SQL-formatted changesets must contain manual `--rollback` statements. Never edit an executed changeset to add or change rollback logic; add a forward corrective changeset instead if a safe rollback is not possible. Rollback is sequential: selecting an older tag also reverses every newer release.

The initial deployment made before this workflow was added has no database checkpoint automatically. The next tagged deployment creates a `pre-db-release-*` checkpoint before changing the database; all later releases have both pre- and post-deployment checkpoints.

## Add the next change

Never edit an executed changeset. Create a new dated file, add it to the master manifest after its dependencies, and open a pull request. Example:

```sql
--liquibase formatted sql
--changeset demo.dba:20260922-01 labels:demo context:demo
ALTER TABLE demo_orders ADD (source_system VARCHAR2(30 CHAR));
--rollback ALTER TABLE demo_orders DROP COLUMN source_system;
```

Then add the new file to the master changelog after every object it depends on. The PR artifact is the SQL a DBA can review before granting the production environment approval.

## Local validation (optional)

With Liquibase installed, run:

```bash
liquibase validate --url='offline:oracle?version=26.0' \
  --changelog-file=database/changelog/db.changelog-master.yaml
liquibase update-sql --url='offline:oracle?version=26.0' \
  --changelog-file=database/changelog/db.changelog-master.yaml
```

The deployed schema user needs normal object-creation privileges (`CREATE TABLE`, `CREATE VIEW`, `CREATE SEQUENCE` if applicable) plus quota on its tablespace. The workflow uses the Oracle JDBC driver bundled with Liquibase 4.32, downloads Oracle's `oraclepki` wallet provider into the ephemeral runner, and passes the extracted wallet directory explicitly with the JDBC `TNS_ADMIN` parameter.
