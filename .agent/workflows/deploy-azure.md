---
description: Build for production and deploy to Azure Blob Storage ($web container)
---

# Deploy to Azure Storage

This workflow builds the Angular app for production and uploads it to the Azure `$web` static website container.

## Prerequisites
- `azcopy` must be installed and available on PATH ([Download](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10))
- The file `/.env.deploy` must exist with the `AZURE_STORAGE_SAS_URL` variable (this file is gitignored)

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
azcopy sync "./dist/browser" "$SAS_URL" --delete-destination=true
```
*(Note: update `./dist/browser` if your build output path differs).*

5. Verify: The site should be available at the Azure static website URL. Execute a basic health check:
```bash
curl -I https://YOUR_STORAGE_ACCOUNT.z1.web.core.windows.net/ | grep "HTTP/1.1 200 OK"
```
*(Replace the URL with the actual project static website endpoint).* Ask the user to confirm deployment.

## Rollback Plan
If deployment fails or the health check does not pass, you can rollback by deploying the previous build artifact if available, or reverting the latest code changes and re-running this workflow.
