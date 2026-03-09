---
description: Build for production and deploy to Azure Blob Storage ($web container)
---

# Deploy to Azure Storage

This workflow builds the Angular app for production and uploads it to the Azure `$web` static website container.

## Prerequisites
- `azcopy` must be installed and available on PATH ([Download](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10))
- The file `/.env.deploy` must exist with the following variables (this file is gitignored):
  - `AZURE_STORAGE_SAS_URL` — Full SAS URL for deployment
  - `AZURE_STATIC_WEBSITE_URL` — Static website endpoint for health checks

## Steps

// turbo
1. Verify that `.env.deploy` exists:
```bash
if [ ! -f "./.env.deploy" ]; then
  echo "Error: Missing .env.deploy — create it with AZURE_STORAGE_SAS_URL"
  exit 1
fi
```

// turbo
2. Load the SAS URL from `.env.deploy`:
```bash
export SAS_URL=$(grep "^AZURE_STORAGE_SAS_URL=" ./.env.deploy | cut -d '=' -f2-)
```

// turbo
3. Build the application for production:
```bash
npx ng build --configuration production
```
Run this step from the root application directory.

4. Upload `dist/` output to Azure using `azcopy sync`:
```bash
if [ -n "$ANGULAR_WORKING_DIRECTORY" ] && [ "$ANGULAR_WORKING_DIRECTORY" != "." ]; then
  BROWSER_DIR="./dist/$ANGULAR_WORKING_DIRECTORY/browser"
else
  BROWSER_DIR="./dist/browser"
fi

azcopy sync "$BROWSER_DIR" "$SAS_URL" --delete-destination=true
```

5. Verify: The site should be available at the Azure static website URL. Execute a basic health check:
```bash
SITE_URL=$(grep "^AZURE_STATIC_WEBSITE_URL=" ./.env.deploy | cut -d '=' -f2-)
curl -I "$SITE_URL" | grep "HTTP/1.1 200 OK"
```
*(Requires `AZURE_STATIC_WEBSITE_URL` in `.env.deploy`).* Ask the user to confirm deployment.

// turbo
6. Create and push a production release tag:
```bash
TAG_NAME="prod-$(date +'%Y%m%d-%H%M')"
git tag "$TAG_NAME"
git push origin "$TAG_NAME"
```

## Rollback Plan
If deployment fails or the health check does not pass, you can rollback by deploying the previous build artifact if available, or reverting the latest code changes and re-running this workflow.