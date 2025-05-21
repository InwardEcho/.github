# GitHub Organizational Workflow Templates

This directory contains a set of standardized, reusable GitHub Actions workflow templates for common CI/CD operations within the organization. These templates are designed to promote consistency, security, and best practices across all C# projects.

## Strategy Overview

The primary goal of these organizational templates is to:
-   **Standardize CI/CD Processes:** Ensure all projects follow similar, vetted processes for building, testing, securing, and deploying applications.
-   **Reduce Boilerplate:** Minimize repetitive workflow code in individual application repositories.
-   **Promote Best Practices:** Embed security scanning, automated testing, and controlled deployments by default.
-   **Simplify Maintenance:** Allow updates to CI/CD logic to be made centrally and rolled out to all consuming projects.
-   **Enhance Observability:** Provide common hooks for notifications and status reporting.

These templates are designed as **callable workflows**. Application repositories will define their own simple workflows that `use` these organizational templates, passing in required parameters and secrets.

## How to Use These Templates

To use an organizational workflow template in your application repository's workflow (e.g., in `.github/workflows/main.yml`):

1.  **Reference the Template:** Use the `jobs.<job_id>.uses` syntax. The exact path will depend on where these organizational templates are hosted. If they are in a central repository (e.g., `your-org/org-workflows`), the path would be:
    ```yaml
    jobs:
      build:
        uses: your-org/org-workflows/.github/workflows/org-build-test-dotnet.yml@main # Or a specific tag/branch
        with:
          # Provide necessary inputs
          dotnet-version: '8.0.x'
          solution-path: './MySolution.sln'
        secrets: # Pass necessary secrets
          NUGET_API_KEY_SECRET: ${{ secrets.YOUR_NUGET_API_KEY }} # Example
    ```
    If these templates are configured as "Workflow Templates" at the organization level (discoverable via the "New workflow" UI), the mechanism might differ slightly, but the core concept of calling them remains. The path for `uses` must be the full path to the reusable workflow file within the organization.

2.  **Provide Inputs:** Each template defines a set of `inputs` that allow you to customize its behavior (e.g., .NET version, project paths, environment names). Refer to the individual template's YAML file for its specific inputs.

3.  **Provide Secrets:** Many templates require secrets (e.g., API keys, connection strings). These must be defined in the calling repository's secrets configuration and passed to the template using the `secrets` block (e.g., `secrets: inherit` or `secrets: MY_TEMPLATE_SECRET: ${{ secrets.CALLER_SECRET }}`).

## Available Workflow Templates

Below is a list of the available organizational workflow templates. Each `.yml` file is accompanied by a `.properties.json` file that provides metadata for UI discovery (if configured at the org level).

1.  **[`org-build-test-dotnet.yml`](org-build-test-dotnet.yml:1)**
    *   **Purpose:** Compiles, tests (.NET unit, integration), and packages C# applications.
    *   **Key Features:** Handles multiple .NET versions, solution/project paths, build configurations, NuGet caching, test reporting, and artifact generation.

2.  **[`org-versioning.yml`](org-versioning.yml:1)**
    *   **Purpose:** Calculates application versions using GitVersion based on Git history and tags.
    *   **Key Features:** Outputs SemVer 2.0 versions, supports pre-release concepts.

3.  **[`org-publish-nuget.yml`](org-publish-nuget.yml:1)**
    *   **Purpose:** Publishes NuGet packages to a specified feed (e.g., GitHub Packages, Azure Artifacts).
    *   **Key Features:** Takes package version and path as input, handles feed authentication.

4.  **[`org-security-github.yml`](org-security-github.yml:1)**
    *   **Purpose:** Orchestrates GitHub's native CodeQL (SAST) security scanning.
    *   **Key Features:** Configurable language and build process for CodeQL analysis. (Note: GitHub Secret Scanning and Dependency Review are primarily platform features configured at the repository/organization level.)

5.  **[`org-iac-terraform.yml`](org-iac-terraform.yml:1)**
    *   **Purpose:** Standardizes Terraform (Infrastructure as Code) operations.
    *   **Key Features:** Supports `terraform init`, `validate`, `fmt`, `plan`, and `apply`. Manages workspaces and backend configurations.

6.  **[`org-deploy-environment.yml`](org-deploy-environment.yml:1)**
    *   **Purpose:** Generic workflow for deploying applications to various environments (dev, test, staging, prod).
    *   **Key Features:** Handles environment-specific configurations, calls deployment tools/scripts (e.g., Azure App Service, Kubernetes), and performs basic health checks.

7.  **[`org-promote-environment.yml`](org-promote-environment.yml:1)**
    *   **Purpose:** Manages controlled promotion of builds/artifacts between environments, integrating with GitHub Environment approval gates.
    *   **Key Features:** Validates promotion paths, designed to be called by a `workflow_dispatch` trigger in the consuming repository which is linked to a GitHub Environment protection rule.

8.  **[`org-canary-deployment.yml`](org-canary-deployment.yml:1)**
    *   **Purpose:** Orchestrates a canary release strategy to minimize deployment risk.
    *   **Key Features:** Deploys to a canary subset, monitors (via script or timed wait), and then facilitates full rollout or rollback, often integrated with manual approvals via GitHub Environments.

9.  **[`org-database-migration-efcore.yml`](org-database-migration-efcore.yml:1)**
    *   **Purpose:** Manages Entity Framework Core database schema migrations automatically and safely.
    *   **Key Features:** Optional pre-migration backup (via script), applies EF Core migrations, handles environment-specific connection strings.

10. **[`org-observability-hooks.yml`](org-observability-hooks.yml:1)**
    *   **Purpose:** Standardizes pipeline status notifications to channels like Slack and Microsoft Teams.
    *   **Key Features:** Captures common workflow context (status, repo, branch, actor, run URL) for rich notifications.

11. **[`org-deploy-azure-app-service.yml`](org-deploy-azure-app-service.yml:1)**
    *   **Purpose:** Deploys C# applications specifically to Azure App Service.
    *   **Key Features:** Handles Azure login, deployment to a specific App Service and slot, package deployment, and App Service-specific configurations.

12. **[`org-deploy-kubernetes.yml`](org-deploy-kubernetes.yml:1)**
    *   **Purpose:** Deploys containerized applications to a Kubernetes cluster.
    *   **Key Features:** Handles Kubernetes context setup (via kubeconfig or cloud provider CLI), applies manifest files (YAML), uses `kubectl` or can be adapted for Helm, and supports namespace management.

13. **[`org-deploy-custom-script.yml`](org-deploy-custom-script.yml:1)**
    *   **Purpose:** Deploys an application using a custom user-provided script (e.g., Bash, PowerShell, Python).
    *   **Key Features:** Flexible deployment logic, passes artifact paths and environment details to the script, and can perform basic post-deployment health checks via script output or a URL.

14. **[`org-static-code-analysis.yml`](org-static-code-analysis.yml:1)**
    *   **Purpose:** Integrates with SonarCloud (or a self-hosted SonarQube instance) to perform static code analysis.
    *   **Key Features:** Supports various languages (configurable JDK, .NET SDK, Node.js versions), handles SonarScanner execution, PR decoration, and quality gate checks.

15. **[`org-release-notes.yml`](org-release-notes.yml:1)**
    *   **Purpose:** Automates the generation and creation/update of GitHub Release notes.
    *   **Key Features:** Can use GitHub's auto-generated notes or a custom body, manages draft/prerelease status, and associates notes with a specific tag.

16. **[`org-dependency-update.yml`](org-dependency-update.yml:1)**
    *   **Purpose:** Provides a handler for actions after dependency updates (e.g., from Dependabot merges) and includes an informational check for `dependabot.yml` configuration.
    *   **Key Features:** Can run tests on updated code, send notifications, and reminds users about Dependabot setup.

## General Guidance

*   **Secrets Management:** Always store sensitive information like API keys, connection strings, and tokens as encrypted secrets in GitHub. Refer to them in your calling workflows and pass them to these templates as needed.
*   **Idempotency:** Where possible, deployment and infrastructure tasks should be designed to be idempotent, meaning running them multiple times with the same inputs yields the same result.
*   **Testing Templates:** Changes to these organizational templates should be tested thoroughly, ideally in a non-production organization or with pilot projects, before being rolled out widely.
*   **Versioning Templates:** Consider using release tags (e.g., `v1.0.0`, `v1.1.0`) for these templates so that consuming workflows can pin to specific versions for stability, e.g., `uses: your-org/org-workflows/.github/workflows/template.yml@v1.0.0`.

## Example Caller Workflow Snippet

Here's a conceptual example of how an application repository might define a CI workflow using some of these templates:

```yaml
# .github/workflows/main-ci.yml in an application repository
name: Application CI Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  calculate_version:
    name: Calculate Version
    uses: your-org/org-workflows/.github/workflows/org-versioning.yml@main # Replace with actual path
    # No inputs needed if using default GitVersion config from repo
    # or pass inputs.use-config-file: true if GitVersion.yml is present

  build_and_test:
    name: Build and Test .NET App
    needs: calculate_version
    uses: your-org/org-workflows/.github/workflows/org-build-test-dotnet.yml@main # Replace with actual path
    with:
      dotnet-version: '8.0.x'
      solution-path: './src/MyApplication.sln' # Path to your solution
      artifact-name-prefix: 'my-app-${{ needs.calculate_version.outputs.semver }}'
      upload-artifacts: true
    secrets: inherit # Or pass specific secrets

  security_scan:
    name: CodeQL Security Scan
    needs: build_and_test # Run after build to ensure code is ready
    uses: your-org/org-workflows/.github/workflows/org-security-github.yml@main # Replace with actual path
    with:
      language: 'csharp' # Or other supported language
      # Ensure build commands are compatible if not using autobuild

  notify_on_status:
    name: Notify Build Status
    if: always() # Run regardless of previous job status
    needs: [calculate_version, build_and_test, security_scan] # Depends on all critical jobs
    uses: your-org/org-workflows/.github/workflows/org-observability-hooks.yml@main # Replace with actual path
    with:
      status: ${{ needs.build_and_test.result }} # Result of the build_and_test job
      # Other inputs like workflow-name, actor, etc., will use defaults from context
      send-slack-notification: true
      custom-message: "Build and test for version ${{ needs.calculate_version.outputs.semver }} completed."
    secrets:
      SLACK_WEBHOOK_URL: ${{ secrets.ORG_SLACK_CICD_WEBHOOK }} # App repo secret
```

This `README.md` provides a starting point. It should be expanded with more specific details as the organizational setup for these templates is finalized (especially the exact `uses:` paths).