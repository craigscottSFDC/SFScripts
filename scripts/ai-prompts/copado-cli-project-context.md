# Project Context: Salesforce DX + Copado CLI (Fully Automated)

This project is a Salesforce DX repository managed via the Copado CLI (`sf copado`). 
Copado automatically governs feature branches, tracking, and git commit structures. 
Claude acts as the local executor, optimizing workspace readiness, resolving metadata conflicts, and fixing deployment gates.

## 1. Core DevOps Commands

### Authentication & Connection
- **Check Auth Status:** `sf copado:auth:display --showdetails`
- **Link Copado to Auth User:** `sf copado:auth:set -u <Copado_Production_Hub_Username>`
- **Authenticate Salesforce Org:** `sf org login web`

### Pipeline & Story Management
- **Set/Switch User Story Workspace:** `sf copado:work:set --story <Story_ID>`
- **Push Local Changes to Copado:** `sf copado:work:push`
- **Validate Story Pipeline:** `sf copado:work:submit -v`
- **Promote & Deploy Story:** `sf copado:work:submit -d`

### Local Safeguards
- **Local Validation:** `sf project deploy validate --source-dir force-app`
- **Run Local Apex Tests:** `sf apex run test --specified-tests <TestClass> --result-format human`

---

## 2. Execution Rules & Agentic Workflows

### Session & Auth Verification (Pre-Flight Check)
Whenever a Copado command fails with an error indicating an unauthenticated user or connection timeout:
1. Intercept the failure and run `sf copado:auth:display`.
2. If no valid user is linked, scan the local authenticated orgs using `sf org list`.
3. If the Copado Hub org username is found in the list, automatically attempt to heal the connection:
   `sf copado:auth:set -u <username>`
4. If the org is completely unauthenticated, stop and instruct the user: 
   *"Please authenticate your Copado Hub Org by running: sf org login web"*

### Staging & Syncing Work
When a user provides a Copado User Story ID to sync changes:
1. **Enforce Story Context:** Run `sf copado:work:set --story <Story_ID>` to align the automated feature branch.
2. **Stage Changes:** Run `git add .` to capture all untracked/modified Salesforce metadata.
3. **Hand-Off:** Execute `sf copado:work:push`. Allow Copado to entirely control the commit message wrapper and Git metadata syncing.

### Resolving Automated Merge Conflicts
If Git halts on a merge conflict during a back-promotion or upstream rebase:
1. Examine the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) inside the Salesforce XML or Apex code.
2. Ensure the resulting XML schema remains structurally valid (never drop or misalign structural closures like `</fields>` or `</CustomObject>`).
3. For profile or permission configurations, preserve both blocks unless a clear regression is identified.
4. Stage the files (`git add .`) when fixed and prompt the user to proceed with the push.

### Self-Healing Validation Loops
When requested to validate or push for a specific story:
1. Execute the validation command (`sf copado:work:submit -v`).
2. If the pipeline reports a deployment error or Apex test failure:
   - Identify the exact code line, rule violation, or missing dependency from the terminal error logs.
   - Edit the local file to fix the compilation error, test dataset deficiency, or null pointer.
   - Run a quick local test (`sf apex run test`) to verify the patch.
   - Push the fix using `sf copado:work:push` to let Copado restart the validation.
3. Maximum loop capacity: **2 automatic adjustment attempts**. If the error persists, pause and output the stack trace for user review.
