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
```powershell
if (-not (Test-Path "r:\Projects\le-cementine\.env.deploy")) { Write-Error "Missing .env.deploy — create it with AZURE_STORAGE_SAS_URL"; exit 1 }
```

// turbo
2. Load the SAS URL from `.env.deploy`:
```powershell
$sasUrl = (Get-Content "r:\Projects\le-cementine\.env.deploy" | Where-Object { $_ -match "^AZURE_STORAGE_SAS_URL=" }) -replace "^AZURE_STORAGE_SAS_URL=", ""
```

// turbo
3. Build the application for production:
```powershell
npx ng build --configuration production
```
Run from `r:\Projects\le-cementine\lc-webapp`.

4. Upload `dist/lc-webapp/browser` to Azure using `azcopy sync`:
```powershell
azcopy sync "r:\Projects\le-cementine\lc-webapp\dist\lc-webapp\browser" "$sasUrl" --delete-destination=true
```
This syncs the build output to the `$web` container, removing any files in the destination that are no longer in the source.

5. Verify. The site should be available at the Azure static website URL. Ask the user to confirm deployment.
