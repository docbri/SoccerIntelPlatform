# Staging Environment Current Requirements

## GitHub Environment: staging

### Secrets
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Variables
- `AZURE_WEBAPP_NAME`

## Azure Identity
- Federated credential subject:
  - `repo:docbri/SoccerIntelPlatform:environment:staging`

## Azure RBAC
- App deployment permission for `github-soccerintel-staging`
- Storage Blob Data Contributor for remote state backend access

