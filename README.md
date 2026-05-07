# Delete Git Tag from Repository GitHub Action

This GitHub Action deletes a git tag from your repository using the GitHub REST API and PowerShell.  
It is designed to be simple, composable, and independent of the local git state.

## Features

- Deletes a tag from your repository via the REST API (no dependencies on local git or CLI).
- Lets you specify the tag name, organization, and repository.
- Fully supports GitHub Organizations and user-owned repositories.
- Outputs the tag deletion result and error message (if any) for use in subsequent workflow steps.
- Designed for secure automation with the minimal required token permissions.

## Inputs

| Name        | Description                                | Required | Default |
|-------------|--------------------------------------------|----------|---------|
| `tag-name`  | Name of the tag to delete                  | Yes      |         |
| `org-name`  | The name of the GitHub organization        | Yes      |         |
| `repo-name` | The name of the repository                 | Yes      |         |
| `token`     | GitHub token with access to Git tags       | Yes      |         |

## Outputs

| Name            | Description                                                                                   |
|-----------------|----------------------------------------------------------------------------------------------|
| `result`        | Result of the attempt to delete the git tag (`success`, `not-found`, or `failure`)           |
| `error-message` | Error message if the action fails                                                            |

## Usage

Create a workflow file in your repository (e.g., `.github/workflows/delete-tag.yml`).  
**Ensure you pass all required inputs and use a valid token with tag deletion access.**

### Example Workflow

```yaml
name: Delete Git Tag
on:
  workflow_dispatch:

jobs:
  delete-tag:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v6

      - name: Delete Git Tag via API
        id: delete-tag
        uses: lee-lott-actions/delete-git-tag@v1
        with:
          tag-name: 'v1.0.0'
          repo-name: ${{ github.event.repository.name }}
          org-name: ${{ github.repository_owner }}
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Output Delete Result
        run: |
          echo "Delete Result: ${{ steps.delete-tag.outputs.result }}"
          echo "Error Message: ${{ steps.delete-tag.outputs.error-message }}"
```
