# Platform Operations (Staging)

## Purpose

Describe how to plan, bring up, verify, resume, operate ingestion, operate local Bronze consumption, tear down, and explicitly reset the SoccerIntelPlatform staging platform from source control.

The public operational entry point is:

    ./scripts/platform.sh

Lower-level scripts such as `scripts/up-staging.sh`, `scripts/up-redpanda.sh`, `scripts/destroy-staging.sh`, `scripts/destroy-redpanda.sh`, and `scripts/deploy-platform-api.sh` are implementation details. Operators should use `platform.sh` unless they are intentionally debugging one subordinate script.

---

## Operational Model

The current staging lifecycle is:

    ./scripts/platform.sh plan
    ./scripts/platform.sh up
    ./scripts/platform.sh resume
    ./scripts/platform.sh verify
    ./scripts/platform.sh ingest once
    ./scripts/platform.sh ingest poll --pph 1
    ./scripts/platform.sh ingest status
    ./scripts/platform.sh ingest stop
    ./scripts/platform.sh bronze consume
    ./scripts/platform.sh bronze status
    ./scripts/platform.sh bronze stop
    ./scripts/platform.sh down
    ./scripts/platform.sh reset

Meaning:

- `plan` generates a non-mutating staging OpenTofu plan.
- `up` reconciles staging infrastructure, authenticates Databricks for the current workspace, deploys Platform.Api to the staging slot, brings up Redpanda, deploys/runs the Databricks bundle, and verifies the platform.
- `resume` does not recreate infrastructure. It redeploys/runs Databricks bundle resources and verifies the platform after idle runtime timeout.
- `verify` validates Azure platform resources, Platform.Api `/health`, the Databricks bundle, and the expected Unity Catalog medallion objects.
- `ingest once` runs one controlled Platform.Worker ingestion pass and publishes to Azure Redpanda.
- `ingest poll --pph <n>` starts Platform.Worker in background polling mode, using a bounded polls-per-hour setting.
- `ingest status` reports whether background ingestion polling is running and shows recent worker logs.
- `ingest stop` stops background ingestion polling without tearing down the platform.
- `bronze consume` starts the local .NET Bronze consumer, subscribes to the Azure Redpanda topic, and writes accepted rows/quarantine rows to local JSONL files.
- `bronze status` reports whether the Bronze consumer is running and shows recent logs plus the tail of the local Bronze/quarantine output files.
- `bronze stop` stops the local Bronze consumer without tearing down Redpanda, Databricks, Platform.Api, or staging infrastructure.
- `down` performs ordinary teardown of bundle resources, Redpanda, and staging infrastructure.
- `reset` is an explicitly destructive staging reset. It requires `CONFIRM_DESTRUCTIVE_RESET=destroy-staging-data`, delegates to the teardown path, and relies on `destroy-staging.sh` to perform project catalog and Unity Catalog storage cleanup before OpenTofu destroy.

Important operational rule:

    ./scripts/platform.sh up

brings up the platform, but it does not start continuous Soccer API polling.  API-consuming ingestion must be started explicitly with `ingest once` or `ingest poll`.

---

## Prerequisites

Required local tools:

- Azure CLI
- OpenTofu
- Databricks CLI
- .NET SDK
- zip
- Git
- `nc` / netcat

Required access:

- Azure subscription access
- Storage Blob Data Contributor access to the OpenTofu remote state backend after bootstrap
- Azure App Service deployment access for Platform.Api
- Databricks workspace access for the operator running Databricks bundle and Unity Catalog verification commands
- Network access from the operator machine to the Redpanda VM public endpoint on port `9092`

---

## 1. Authenticate to Azure

Run from any directory:

    az login
    az account set --subscription "Azure subscription 1"

---

## 2. Confirm Databricks CLI authentication

The staging apply path resolves the Databricks workspace URL from OpenTofu output after infrastructure apply.

When a workspace is rebuilt, the workspace URL can change.  The apply script authenticates the Databricks CLI for the current workspace and switches the default Databricks profile to the profile for that workspace before running Databricks catalog, grant, or verification commands.

The staging workspace host can be inspected from OpenTofu output after infrastructure exists:

    cd infra/terraform/env/staging
    tofu output -raw databricks_workspace_url

A non-mutating authentication check from the repository root is:

    DATABRICKS_HOST="https://$(cd infra/terraform/env/staging && tofu output -raw databricks_workspace_url)" databricks catalogs get soccerintel_staging >/dev/null && echo "Databricks env-host auth OK"

If this fails during normal use, run:

    ./scripts/platform.sh up

The apply path will authenticate the current Databricks workspace.  Do not manually edit Databricks profile files.

---

## 3. Bootstrap OpenTofu remote state

Run from the repository root:

    cd infra/terraform/bootstrap
    tofu init
    tofu apply

This creates the remote state foundation:

- Resource group: `rg-soccerintel-tfstate`
- Storage account: `soccerinteltfstate`
- Blob container: `tfstate`

---

## 4. Plan staging infrastructure

Run from the repository root:

    ./scripts/platform.sh plan

This delegates to the staging OpenTofu planning path and generates:

- `infra/terraform/env/staging/staging.tfplan`
- `infra/terraform/env/staging/staging-plan.txt`

The plan path is intentionally non-mutating.  It should not deploy Databricks bundles, run jobs, apply grants, deploy Platform.Api, start ingestion, or recreate runtime services.

---

## 5. Bring up the staging platform

Run from the repository root:

    ./scripts/platform.sh up

This is the full staging bring-up path.

It performs the following high-level sequence:

- Applies/reconciles staging infrastructure.
- Resolves the Databricks workspace URL from OpenTofu output.
- Authenticates the Databricks CLI for the current workspace.
- Switches the default Databricks profile to the profile for the current workspace.
- Applies Databricks Unity Catalog grants when the CI grant principal is available.
- Verifies the Unity Catalog catalog and schemas.
- Deploys Platform.Api to the App Service staging slot.
- Brings up Redpanda.
- Validates the Databricks bundle using the current workspace profile.
- Deploys the Databricks bundle using the current workspace profile.
- Runs the medallion bundle job using the current workspace profile.
- Verifies Azure platform resources, Platform.Api `/health`, Databricks catalog, schemas, and medallion tables.

The Databricks bundle job currently runs:

- Bronze task
- Silver task
- Gold task

Expected successful task output includes:

    BRONZE INGESTION COMPLETE
    SILVER TRANSFORMATION COMPLETE
    GOLD TRANSFORMATION COMPLETE

Important:

`up` does not start Soccer API polling.  This protects the API-Football daily call budget.

---

## 6. Resume Databricks runtime work after idle timeout

Run from the repository root:

    ./scripts/platform.sh resume

Use `resume` when durable infrastructure already exists but the Databricks runtime path needs to be made usable again.

The current bundle uses job-cluster behavior, so `resume` does not start a long-lived all-purpose cluster.  Instead, it:

- Validates the Databricks bundle using the current workspace profile.
- Deploys the Databricks bundle using the current workspace profile.
- Runs the medallion slice job using the current workspace profile.
- Verifies Azure platform resources, Platform.Api `/health`, catalog, schemas, and tables.

Use `resume` instead of `up` when the platform exists and the goal is to re-run or re-wake the Databricks job path.

---

## 7. Verify platform state

Run from the repository root:

    ./scripts/platform.sh verify

Current verification checks:

- Azure CLI authentication
- Azure resource group: `rg-soccerintel-platform`
- Azure App Service: `app-soccerintel-platform-api`
- Azure App Service slot: `app-soccerintel-platform-api/staging`
- Platform.Api staging health endpoint: `https://app-soccerintel-platform-api-staging.azurewebsites.net/health`
- Redpanda VM: `vm-redpanda-staging`
- Redpanda public IP: `pip-redpanda`
- Databricks bundle validation using the current workspace profile
- Catalog: `soccerintel_staging`
- Schemas:
  - `soccerintel_staging.bronze`
  - `soccerintel_staging.silver`
  - `soccerintel_staging.gold`
- Tables:
  - `soccerintel_staging.bronze.raw_ingestion_events`
  - `soccerintel_staging.silver.league_status_events`
  - `soccerintel_staging.gold.current_league_status`

Expected successful verification ends with:

    Platform verification completed.

---

## 8. Controlled ingestion operations

The ingestion commands run `Platform.Worker` from the local machine and publish to the Azure Redpanda VM.

By default, the script resolves the Azure Redpanda public IP from:

- Resource group: resolved from `infra/terraform/env/staging/terraform.tfvars`, unless `AZURE_RESOURCE_GROUP` is set
- Public IP resource: `pip-redpanda`
- Port: `9092`

The script verifies TCP connectivity before starting the worker.

### Run one controlled ingestion pass

Run:

    ./scripts/platform.sh ingest once

This command:

- Resolves the Azure Redpanda public endpoint.
- Verifies TCP connectivity to Redpanda on port `9092`.
- Runs `src/Platform.Worker/Platform.Worker.csproj` once.
- Publishes one ingestion pass to the Kafka topic configured for the worker.
- Exits after the controlled pass completes.

Expected successful output includes:

    TCP connectivity verified: <redpanda-ip>:9092
    Running one controlled ingestion pass.
    Kafka bootstrap server: <redpanda-ip>:9092
    Published envelope to Kafka topic soccer.raw.ingestion.dev

### Start background polling

Run:

    ./scripts/platform.sh ingest poll --pph 1

This command starts Platform.Worker in background polling mode.

The `--pph` value means polls per hour.  For example:

- `--pph 1` means one poll per hour.
- `--pph 2` means two polls per hour.
- `--pph 4` means four polls per hour.

The script converts this value into `--poll-interval-seconds` before calling the worker.

With the default daily API-Football call ceiling of `100`, `--pph 4` is the normal maximum because:

    4 polls/hour × 24 hours = 96 polls/day

The script rejects unsafe values.  For example:

    ./scripts/platform.sh ingest poll --pph 5

fails because:

    5 polls/hour × 24 hours = 120 polls/day

which exceeds the default daily maximum of `100`.

### Check ingestion status

Run:

    ./scripts/platform.sh ingest status

This command reports:

- Whether background ingestion polling is running.
- The stored worker process ID, if present.
- The most recent polling configuration from `.runtime/platform-ingest.env`.
- The tail of `.runtime/platform-worker.log`, if present.

### Stop background polling

Run:

    ./scripts/platform.sh ingest stop

This command stops the background polling process without tearing down Redpanda, Databricks, Platform.Api, or staging infrastructure.

Use this when polling is no longer needed so the worker does not continue consuming API-Football calls.

### Override the Redpanda bootstrap server

The default ingestion path publishes to Azure Redpanda.

For a one-off override, pass:

    ./scripts/platform.sh ingest once --bootstrap-server localhost:9092

or:

    ./scripts/platform.sh ingest poll --pph 1 --bootstrap-server localhost:9092

For an environment-level override, set:

    REDPANDA_BOOTSTRAP_SERVER=localhost:9092 ./scripts/platform.sh ingest once

Use overrides deliberately.  The normal staging path should publish to the Azure Redpanda VM.

---

## 9. API-Football daily call budget

The API-Football license currently allows a maximum of `100` calls per day.

The default script value is:

    API_FOOTBALL_MAX_CALLS_PER_DAY=100

The default polling frequency is:

    INGEST_DEFAULT_POLLS_PER_HOUR=1

The worker stores the API call ledger at:

    localdata/api-football-call-ledger.json

The script passes this path explicitly through:

    API_FOOTBALL_CALL_LEDGER_PATH

so the ledger is written at the repository root rather than under `src/Platform.Worker` or `src/Platform.Worker/bin`.

When the API key is missing or is a development placeholder, the worker publishes a synthetic warning envelope and does not reserve daily API quota.

Expected placeholder-key output includes:

    API-Football API key is not configured with a real value.
    The worker will publish synthetic warning envelopes and will not reserve daily API quota.

A placeholder-key run should not create `api-football-call-ledger.json`.

When a real API key is configured, each actual API-Football call is guarded by the ledger.  If the daily max is reached, the worker skips additional calls for that UTC day.

To inspect the ledger:

    find . -name 'api-football-call-ledger.json' -print -exec cat {} \;

To remove accidental local ledgers during development:

    find . -name 'api-football-call-ledger.json' -delete

Do not delete the ledger casually when using a real API key, because it exists to protect the daily API call budget.

---

## 10. Local Bronze consumption operations

The Bronze commands run `Platform.BronzeConsumer` from the local machine and consume from the Azure Redpanda VM.

This is the current operational bridge between Redpanda and Bronze-shaped storage:

    Platform.Worker
        → Azure Redpanda topic soccer.raw.ingestion.dev
        → Platform.BronzeConsumer
        → localdata/bronze/raw_ingestion_events.jsonl
        → localdata/quarantine/raw_ingestion_quarantine.jsonl

The local Bronze consumer is not yet the final Databricks Bronze ingestion path.  It is the operational proof that the Worker envelope contract, Kafka transport, validation, idempotency, Bronze row mapping, and quarantine handling work end-to-end before replacing the hard-coded Databricks Bronze smoke path.

### Start the Bronze consumer

Run:

    ./scripts/platform.sh bronze consume

This command:

- Resolves the Azure Redpanda public endpoint.
- Verifies TCP connectivity to Redpanda on port `9092`.
- Runs `src/Platform.BronzeConsumer/Platform.BronzeConsumer.csproj` in the background.
- Subscribes to `soccer.raw.ingestion.dev`.
- Writes valid Bronze rows to `localdata/bronze/raw_ingestion_events.jsonl`.
- Writes invalid or malformed messages to `localdata/quarantine/raw_ingestion_quarantine.jsonl`.
- Stores runtime state under `.runtime/platform-bronze-consumer.env`.
- Stores logs under `.runtime/platform-bronze-consumer.log`.

Expected successful output includes:

    Starting Bronze consumer.
    Kafka bootstrap server: <redpanda-ip>:9092
    Topic name: soccer.raw.ingestion.dev
    Bronze consumer started with PID <pid>.

### Check Bronze consumer status

Run:

    ./scripts/platform.sh bronze status

This command reports:

- Whether the Bronze consumer is running.
- The stored process ID, if present.
- The most recent Bronze consumer configuration.
- The tail of `.runtime/platform-bronze-consumer.log`.
- The tail of `localdata/bronze/raw_ingestion_events.jsonl`.
- The tail of `localdata/quarantine/raw_ingestion_quarantine.jsonl`.

### Stop the Bronze consumer

Run:

    ./scripts/platform.sh bronze stop

This stops the local Bronze consumer without tearing down the platform.

Use this after local Redpanda-to-Bronze testing is complete.

### Prove Worker → Redpanda → Bronze

Run:

    ./scripts/platform.sh bronze consume
    sleep 5
    ./scripts/platform.sh ingest once
    sleep 5
    ./scripts/platform.sh bronze status
    ./scripts/platform.sh bronze stop

Expected successful evidence includes:

    Published envelope to Kafka topic soccer.raw.ingestion.dev at offset <n>
    Wrote Bronze row for topic soccer.raw.ingestion.dev partition 0 offset <n>.

The same Kafka offset should appear in the worker publish output, the Bronze consumer log, and the local Bronze JSONL row.

### Bronze idempotency rule

The local Bronze consumer uses Kafka transport identity for idempotency:

    kafka_topic | kafka_partition | kafka_offset

This is intentional.  Bronze should preserve ingested transport events.  Business-level deduplication belongs later in Silver or Gold, not in the raw Bronze capture path.

---

## 11. Tear down staging

Run from the repository root:

    ./scripts/platform.sh down

This is the ordinary public teardown path.

It currently delegates to lower-level teardown behavior for:

- Databricks bundle resources, where applicable
- Redpanda
- Staging infrastructure

The staging destroy path performs project Unity Catalog cleanup before OpenTofu destroy:

- Lists Databricks catalogs.
- Deletes project catalogs matching:
  - `soccerintel_staging`
  - `adb_soccerintel_staging_*`
- Deletes external location: `soccerintel-staging-storage`
- Deletes storage credential: `soccerintel-staging-credential`
- Runs OpenTofu destroy.
- Cleans only the Databricks CLI profile associated with the destroyed workspace.

Do not call subordinate destroy scripts directly unless intentionally debugging a specific layer.

---

## 12. Destructive staging reset

Use this only when intentionally preparing for a full rebuild rehearsal.

Run from the repository root:

    CONFIRM_DESTRUCTIVE_RESET=destroy-staging-data ./scripts/platform.sh reset

This command is intentionally guarded.  Running `./scripts/platform.sh reset` without `CONFIRM_DESTRUCTIVE_RESET=destroy-staging-data` fails without deleting data.

The reset path delegates to the ordinary teardown path after confirmation.  The destructive behavior is the project catalog and Unity Catalog storage cleanup performed by `destroy-staging.sh`.

---

## Redpanda SSH Key Note

The Redpanda VM module expects an SSH public key at:

    ~/.ssh/id_rsa.pub

In `plan` mode, the staging script avoids generating a new SSH key when the Redpanda VM already exists.  It reads the existing Redpanda public key from OpenTofu state and writes it to the expected public key path.

This prevents `tofu plan` from forcing an unnecessary Redpanda VM replacement due to an artificial SSH key change.

In `apply` mode, the staging script ensures an SSH key pair exists before applying infrastructure.

---

## Databricks Unity Catalog Grant Note

The staging apply path can apply Unity Catalog grants for the CI principal when `AZURE_CLIENT_ID` is present.

In GitHub Actions, `AZURE_CLIENT_ID` is supplied by the staging environment secrets.

Locally, if `AZURE_CLIENT_ID` is not set, the script skips grant mutation and continues verification using the current Databricks CLI authentication context.

The grants currently applied for the CI principal are:

- `USE CATALOG` on `soccerintel_staging`
- `USE SCHEMA` on `soccerintel_staging.bronze`
- `USE SCHEMA` on `soccerintel_staging.silver`
- `USE SCHEMA` on `soccerintel_staging.gold`

Storage credential and external location grant automation is handled through the staging destroy path during teardown/reset, not through manual table deletion in `platform.sh`.

---

## Platform.Api Deployment Note

`./scripts/platform.sh up` deploys Platform.Api to the App Service staging slot before verification.

The deployment path is implemented by:

    ./scripts/deploy-platform-api.sh

That script publishes:

    src/Platform.Api/Platform.Api.csproj

and deploys the generated zip package to:

    app-soccerintel-platform-api/staging

A successful deployment is verified by:

    https://app-soccerintel-platform-api-staging.azurewebsites.net/health

---

## Databricks Bronze Ingestion Status

The staging medallion bundle now has a working batch Redpanda-to-Bronze path.

Current operational state:

    Platform.Worker
        → Azure Redpanda topic soccer.raw.ingestion.dev
        → Databricks Bronze batch ingestion
        → soccerintel_staging.bronze.raw_ingestion_events
        → Silver transformation
        → Gold current_league_status

The Bronze Databricks task reads available Kafka messages from the configured Redpanda topic, parses the JSON `IngestionEnvelope`, preserves Kafka transport metadata, appends accepted records to Unity Catalog Bronze, and routes invalid records to the Bronze quarantine table.

The current Bronze task is batch-oriented, not long-running streaming. It reads from:

    startingOffsets = earliest
    endingOffsets = latest

and uses Kafka transport metadata for deduplication:

    kafka_topic | kafka_partition | kafka_offset

This means repeated bundle runs can safely re-read the topic while avoiding duplicate Bronze rows for offsets already written.

The active Databricks Bronze task uses:

    databricks/src/bronze/bronze_ingestion_flow.py

The old hard-coded Bronze ingestion flow has been preserved as a smoke-test asset:

    databricks/src/bronze/bronze_smoke_ingestion_flow.py

The Databricks bundle currently receives the Redpanda bootstrap server from the staging bundle variable:

    kafka_bootstrap_servers

For the current staging proof, that value is configured in:

    databricks/databricks.yml

The intended future improvement is for `platform.sh` to resolve the Redpanda public IP from Azure and pass it into the Databricks bundle run dynamically. Do not replace the working staging value with a placeholder unless the bundle run override path has been verified.

Expected successful Bronze task output includes:

    BRONZE KAFKA INGESTION STARTED
    Accepted rows written: <n>
    Quarantine rows written: <n>
    BRONZE INGESTION COMPLETE

Future work may replace or complement this batch job with checkpointed structured streaming. For now, the staging platform has a working operational medallion slice from controlled Worker ingestion through Redpanda into Databricks Bronze, Silver, and Gold.

---

## Success Criteria

The staging platform is considered up when:

- `./scripts/platform.sh up` completes successfully.
- Azure platform resource verification passes.
- Platform.Api is deployed to the staging slot.
- The Platform.Api staging `/health` endpoint returns HTTP 200.
- Redpanda VM exists and has a public IP.
- The Databricks bundle job terminates successfully.
- Bronze, Silver, and Gold tasks complete.
- `./scripts/platform.sh verify` completes successfully.
- The expected medallion tables exist:
  - `soccerintel_staging.bronze.raw_ingestion_events`
  - `soccerintel_staging.silver.league_status_events`
  - `soccerintel_staging.gold.current_league_status`

The staging ingestion control plane is considered operational when:

- `./scripts/platform.sh ingest once` resolves the Azure Redpanda public IP.
- `./scripts/platform.sh ingest once` verifies TCP connectivity to Redpanda on port `9092`.
- `./scripts/platform.sh ingest once` publishes an envelope to `soccer.raw.ingestion.dev`.
- `./scripts/platform.sh ingest poll --pph 1` starts background polling.
- `./scripts/platform.sh ingest status` reports the running worker process and recent logs.
- `./scripts/platform.sh ingest stop` stops the worker without tearing down the platform.
- Placeholder-key ingestion runs do not create or increment the API call ledger.

The local Bronze consumer path is considered operational when:

- `./scripts/platform.sh bronze consume` resolves the Azure Redpanda public IP.
- `./scripts/platform.sh bronze consume` verifies TCP connectivity to Redpanda on port `9092`.
- `./scripts/platform.sh bronze consume` starts the local Bronze consumer in the background.
- `./scripts/platform.sh ingest once` publishes an envelope to `soccer.raw.ingestion.dev`.
- The Bronze consumer log reports that the same Kafka offset was written to Bronze.
- `localdata/bronze/raw_ingestion_events.jsonl` contains a row for the consumed Kafka offset.
- `./scripts/platform.sh bronze status` reports the running process and recent logs.
- `./scripts/platform.sh bronze stop` stops the consumer without tearing down the platform.

The Databricks Bronze ingestion path is considered operational when:

- `./scripts/platform.sh ingest once` publishes an envelope to `soccer.raw.ingestion.dev`.
- `./scripts/platform.sh resume` validates and deploys the Databricks bundle.
- The Databricks Bronze task reports `BRONZE KAFKA INGESTION STARTED`.
- The Databricks Bronze task writes accepted rows from Redpanda into `soccerintel_staging.bronze.raw_ingestion_events`.
- The Databricks Bronze task reports `BRONZE INGESTION COMPLETE`.
- The Silver task reports `SILVER TRANSFORMATION COMPLETE`.
- The Gold task reports `GOLD TRANSFORMATION COMPLETE`.
- `./scripts/platform.sh verify` completes successfully.
