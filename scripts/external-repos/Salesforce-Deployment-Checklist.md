# Salesforce Deployment Checklist

https://github.com/craigscottSFDC/Salesforce-Deployment-Checklist

A web-based deployment tracking tool for Salesforce release managers. Available as both a standalone Node.js/Express web app and a native Salesforce Lightning Web Component (LWC), both styled with SLDS.

## What's included

- **8 deployment phases** with 48 pre-built checklist items covering the full release lifecycle
- **Inline editing** — update task descriptions, owners, and priorities directly in the UI
- **Status tracking** — mark items complete with a live progress bar per phase
- **Accordion sections** — collapse phases to focus on what's in progress
- **Filtering** — filter tasks by status, owner, or priority
- **Checklist templates** — save and reload deployment templates across releases
- **Confetti on completion** — celebrates a successful deployment

## Implementations

- **Node.js / Express** (`server.js`, `public/`) — runs locally or on any Node host, uses atomic JSON file writes with serialised locks for data safety. Requires Node.js v18+.
- **Salesforce LWC** (`force-app/`) — deploys directly into a Salesforce org as a Lightning component. Uses Apex with `WITH USER_MODE` for field-level security enforcement.

## Tech stack

JavaScript · HTML · CSS · Apex · Salesforce CLI
