# GitHub Pages Deployment Process

This document describes the full process followed to deploy the Terraform project as a GitHub Pages site.
It includes setup, the static site creation, workflow configuration, and the errors encountered with their resolution.

## 1. Goal

Deploy the website created in the Terraform project to GitHub Pages, with a final target URL of:

- `https://wilson-devops.github.io/`

## 2. Static site creation

### 2.1 Create `docs/index.html`

A static HTML page was created in `docs/index.html` using the content that had previously been written into EC2 user data in `main.tf`.
The page includes:

- a dark/light theme toggle
- embedded profile image via inline base64 JPEG data
- sections for Home, About, Skills, Projects, Certifications, Resume, and Contact

### 2.2 Image embedding

The existing base64 file `IMG_9966-tiny.base64` was used to embed the profile image directly in the HTML.
The file contents were confirmed with PowerShell and inserted into the `src="data:image/jpeg;base64,..."` attribute.

## 3. GitHub Actions workflow

A new workflow file was created at `.github/workflows/deploy-github-pages.yml`.
The workflow is configured to:

- run on push to `main`
- checkout the repository
- configure GitHub Pages
- upload the `docs/` folder as the Pages artifact
- deploy the Pages site

## 4. README update

`README.md` was updated with instructions for GitHub Pages deployment, including:

- where the static site is located (`docs/index.html`)
- how to enable GitHub Pages
- the expected root URL for deployment

## 5. Git initialization and push process

### 5.1 Initialize git repository

The local folder was not initially a Git repo, so the following commands were run:

```bash
cd "c:/Users/wmanda/90days-awsdevops/Terraform"
git init
git add .
git commit -m "Add GitHub Pages site"
```

### 5.2 Error: invalid path `nul`

An error occurred when adding files to git:

- `error: invalid path 'nul'`

This happened because there was a file named `nul` in the repository root.

#### Resolution

The invalid file was removed, then the git add/commit sequence was repeated successfully.

### 5.3 Remote push attempt

A GitHub remote was added:

```bash
git remote add origin https://github.com/Wilson-Devops/Terraform.git
```

Then the push failed with:

- `remote: Repository not found.`
- `fatal: repository 'https://github.com/Wilson-Devops/Terraform.git/' not found`

#### Resolution

This error was caused by the target repository not existing on GitHub or lacking access rights.
The correct repository for root GitHub Pages deployment was identified as:

- `https://github.com/Wilson-Devops/wilson-devops.github.io.git`

## 6. Final deployment recommendation

To publish the site at `https://wilson-devops.github.io/`, the repository must be named exactly:

- `wilson-devops.github.io`

### Final commands to run after repo creation

```bash
cd "c:/Users/wmanda/90days-awsdevops/Terraform"
git remote remove origin
git remote add origin https://github.com/Wilson-Devops/wilson-devops.github.io.git
git push -u origin main
```

### GitHub Pages configuration

In the repository settings on GitHub, enable Pages with:

- Branch: `main`
- Folder: `/docs`

## 7. Notes

- If the repo remains named `Terraform`, the Pages URL would be:
  - `https://wilson-devops.github.io/Terraform/`
- For root-level Pages at `https://wilson-devops.github.io/`, repository naming is required.

## 8. Files created

- `docs/index.html`
- `.github/workflows/deploy-github-pages.yml`
- `GITHUB_PAGES_DEPLOYMENT.md`
