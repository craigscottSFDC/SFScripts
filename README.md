# Script Archive

A searchable, self-hosted archive for Salesforce scripts, SOQL queries, and CLI commands — accessible as a static web app via GitHub Pages.

🔗 **[craigscottSFDC.github.io/SFScripts](https://craigscottSFDC.github.io/SFScripts/)**

---

## Features

- **Full-text search** across filenames, file content, tags, descriptions, and bundle notes
- **Bundles** — group related scripts into ordered, step-by-step sequences (e.g. a pre-check SOQL + Apex script + verification SOQL)
- **Syntax highlighting** for Apex, SOQL, SQL, JavaScript, Bash, JSON, XML, and more
- **Filter by file type** using extension chips
- **One-click copy** for any file or bundle step
- **Keyboard navigation** — arrow keys to move through results, `←`/`→` to step through bundle tabs
- No server required — runs entirely as a static site

---

## Adding Scripts

### Single file

Drop any file into a subfolder under `scripts/`:

```
scripts/
  my-category/
    my-script.cls
```

Then rebuild the index and push:

```bash
node build.js
git add .
git commit -m "add my-script"
git push
```

GitHub Actions will automatically deploy to GitHub Pages.

### Bundle (multi-step scripts)

Create a subfolder with a `steps.json` file to group related scripts into a bundle:

```
scripts/
  my-category/
    my-bundle/
      steps.json
      1_pre_check.soql
      2_run_script.cls
      3_verify.soql
```

**`steps.json` format:**

```json
{
  "title": "My Bundle Name",
  "description": "What this bundle does",
  "tags": ["apex", "account"],
  "steps": [
    {
      "file": "1_pre_check.soql",
      "label": "1. Pre-check",
      "note": "Run this first to verify the data state."
    },
    {
      "file": "2_run_script.cls",
      "label": "2. Execute",
      "note": "Run in Anonymous Apex. Check logs for errors."
    },
    {
      "file": "3_verify.soql",
      "label": "3. Verify",
      "note": "Should return 0 rows if successful."
    }
  ]
}
```

---

## Adding Tags & Descriptions

Edit `metadata.json` to add tags and descriptions to individual files:

```json
{
  "scripts/my-category/my-script.cls": {
    "tags": ["apex", "account", "cleanup"],
    "description": "What this script does"
  }
}
```

For bundles, tags and description are defined directly in `steps.json`.

---

## Running Locally

```bash
node build.js    # regenerate search-index.json
npx serve .      # serve at http://localhost:3000
```

> Chrome and Edge can open `index.html` directly from the filesystem. Firefox requires the local server due to `fetch` restrictions.

---

## Project Structure

```
SFScripts/
  index.html              # search UI
  build.js                # index generator
  metadata.json           # tags & descriptions for individual files
  search-index.json       # auto-generated, committed to repo
  package.json
  images/
    script-archive-logo.png
  scripts/
    apex-jobs/
    copado/
    flows/
    package-management/
    user-management/
  .github/
    workflows/
      build.yml           # auto-rebuild & deploy on push to main
```

---

## Supported File Types

| Extension | Highlighted as |
|---|---|
| `.cls`, `.trigger`, `.apex` | Apex |
| `.soql`, `.sosl`, `.sql` | SQL |
| `.js` | JavaScript |
| `.ts` | TypeScript |
| `.json` | JSON |
| `.xml` | XML |
| `.html` | HTML |
| `.sh`, `.bash` | Bash |
| `.py` | Python |
| `.md` | Markdown |
| `.txt` | Plain text |
