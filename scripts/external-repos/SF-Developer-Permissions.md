# SF Developer Permissions

https://github.com/craigscottSFDC/SF-Developer-Permissions

Salesforce metadata bundle providing read-only developer access for QA and UAT environments. Allows developers to verify deployed changes and troubleshoot in elevated environments without the risk of inadvertent modifications.

## What's included

- **Developer User profile** — baseline profile with restricted write access
- **Developer_Testing_Access permission set** — grants read access for testing phases
- **Developer_Test_Access permission set group** — bundles the profile and permission set for easy assignment
- **Developer_Test_Access_Muted muting permission set** — removes specific permissions that should not be available in test environments
- **package.xml** — ready-to-deploy manifest

## Usage notes

The metadata contains generic templates. Before deploying, customise the profile and permission set to include project-specific objects, fields, and metadata relevant to your org.
