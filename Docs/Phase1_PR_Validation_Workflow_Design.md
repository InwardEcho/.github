# Phase 1: Pull Request Validation Workflow Design

This document outlines the design for the Pull Request (PR) validation workflow and its directly associated reusable workflows. The primary goal of this phase is to ensure code quality, security, and adherence to standards before changes are merged into the default branch.

## 1. Caller Workflow: `pr-checks.yml`

*   **Filename:** `.github/workflows/pr-checks.yml`
*   **Purpose:** Validates code changes upon pull request creation or update against the default branch (e.g., `main`). This workflow ensures that code meets quality and security standards. It does *not* publish any packages or deploy.
*   **Trigger:**
    ```yaml
    on:
      pull_request:
        branches:
          - main # Or your organization's default branch name
        types: [opened, synchronize, reopened]
    ```
*   **Permissions (Top Level):**
    ```yaml
    permissions:
      contents: read
      pull-requests: write # To post comments or update PR checks (if reusable workflows do this)
      actions: read
      security-events: write # For CodeQL to upload results
    ```
*   **Concurrency:**
    ```yaml
    concurrency:
      group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.sha }}
      cancel-in-progress: true
    ```
*   **Jobs:**
    *   **`validate_pr`**:
        *   `name: Validate Pull Request`
        *   `runs-on: ubuntu-latest`
        *   `outputs:`
            *   `build_test_status: ${{ steps.build_test.outputs.status }}`
            *   `security_scan_status: ${{ steps.security_scan.outputs.status }}`
            *   `sast_status: ${{ steps.sast.outputs.status }}`
        *   **Steps:**
            1.  **Checkout Repository:** Uses `actions/checkout@v4` with `fetch-depth: 0`. [4, 9]
            2.  **Setup .NET SDK:** Uses `actions/setup-dotnet@v4` to install required .NET SDK versions (e.g., 6.0.x, 7.0.x, 8.0.x). [6, 26, 39, 43]
            3.  **Call `reusable-build-test-dotnet.yml`:**
                *   `id: build_test`
                *   `uses: ./.github/workflows/reusable-build-test-dotnet.yml`
                *   `with:`
                    *   `solution-path: '**/*.sln'`
                    *   `build-configuration: 'Release'`
                    *   `dotnet-version-to-use: '8.0.x'` (example)
                    *   `run-tests: true`
                    *   `artifact-name-prefix: 'pr-check'`
            4.  **Call `reusable-security-github.yml`:**
                *   `id: security_scan`
                *   `uses: ./.github/workflows/reusable-security-github.yml`
                *   `with:`
                    *   `enable-codeql: true`
                    *   `codeql-language: 'csharp'`
            5.  **Call `reusable-static-code-analysis.yml`:**
                *   `id: sast`
                *   `uses: ./.github/workflows/reusable-static-code-analysis.yml`
                *   `with:`
                    *   `solution-path: '**/*.sln'`
                    *   `fail-on-issues: true`
                *   `secrets:`
                    *   `SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}` (if applicable)
    *   **`report_pr_status`** (Optional):
        *   `name: Report PR Check Status`
        *   `runs-on: ubuntu-latest`
        *   `needs: [validate_pr]`
        *   `if: always()`
        *   **Steps:**
            1.  **Call `reusable-observability-hooks.yml`:**
                *   `uses: ./.github/workflows/reusable-observability-hooks.yml`
                *   `with:`
                    *   `status: ${{ needs.validate_pr.result }}`
                    *   `workflow-name: ${{ github.workflow }}`
                    *   `pr-number: ${{ github.event.pull_request.number }}`
                    *   `commit-sha: ${{ github.event.pull_request.head.sha }}`
                    *   `run-url: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`
                    *   `notification-channel: 'slack'` (example)
                *   `secrets:`
                    *   `SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL_PR_CHECKS }}`
                    *   `GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}` (if commenting on PR) [3, 8, 19, 30, 34]

## 2. Reusable Workflow: `reusable-build-test-dotnet.yml`

*   **Filename:** `.github/workflows/reusable-build-test-dotnet.yml`
*   **Purpose:** Compiles, tests, and optionally packages .NET applications.
*   **`on: workflow_call:`**
    *   **Inputs:**
        *   `solution-path`: (string, required, default: `**/*.sln`) Path to solution or project.
        *   `build-configuration`: (string, required, default: `Release`) Build configuration.
        *   `dotnet-version-to-use`: (string, optional) Specific .NET SDK version.
        *   `run-tests`: (boolean, optional, default: `true`) Whether to run tests.
        *   `test-project-path`: (string, optional, default: uses `solution-path`) Path to test projects.
        *   `test-filter`: (string, optional, default: `''`) Filter for `dotnet test`.
        *   `test-results-format`: (string, optional, default: `trx`) Test results format.
        *   `test-results-directory`: (string, optional, default: `TestResults`) Output directory for test results.
        *   `package-application`: (boolean, optional, default: `false`) Whether to run `dotnet publish`.
        *   `publish-output-directory`: (string, optional, default: `./publish`) Output for `dotnet publish`.
        *   `artifact-name-prefix`: (string, required) Prefix for uploaded artifacts.
        *   `upload-build-artifacts`: (boolean, optional, default: based on `package-application`) Whether to upload build artifacts.
        *   `upload-test-results-artifact`: (boolean, optional, default: based on `run-tests`) Whether to upload test results.
        *   `cache-nuget-packages`: (boolean, optional, default: `true`) Whether to cache NuGet packages.
    *   **Outputs:**
        *   `status`: ('success' or 'failure') Overall status.
        *   `build-artifact-name`: (string) Name of uploaded build artifact.
        *   `test-results-artifact-name`: (string) Name of uploaded test results artifact.
        *   `published-output-path`: (string) Path to published output.
    *   **Secrets:**
        *   `NUGET_FEED_AUTH_TOKEN`: (optional) Token for private NuGet feeds.
*   **Jobs:**
    *   **`build_and_test_job`**:
        *   `name: Build, Test, and Package`
        *   `runs-on: ubuntu-latest` (or `windows-latest`)
        *   **Steps:** Setup .NET, Cache NuGet, Restore NuGet, Build, Run Tests, Publish Application, Upload Test Results, Upload Build Artifacts, Set status output.

## 3. Reusable Workflow: `reusable-security-github.yml`

*   **Filename:** `.github/workflows/reusable-security-github.yml`
*   **Purpose:** Orchestrates GitHub's native security features (CodeQL). Secret Scanning and Dependency Review are typically configured at the repository/organization level.
*   **`on: workflow_call:`**
    *   **Inputs:**
        *   `enable-codeql`: (boolean, optional, default: `true`) Whether to run CodeQL. [20, 27, 33, 37, 40]
        *   `codeql-language`: (string, optional, default: 'csharp' or auto-detect) Languages for CodeQL.
        *   `codeql-config-file`: (string, optional) Path to custom CodeQL config.
        *   `codeql-query-suite`: (string, optional) Path to custom CodeQL query suite.
        *   `fail-on-codeql-error`: (boolean, optional, default: `false`) Fail if CodeQL tool errors.
        *   `fail-on-codeql-severity`: (string, optional, default: `''`) Minimum CodeQL alert severity to fail job.
    *   **Outputs:**
        *   `status`: ('success' or 'failure') Status of scan execution.
        *   `codeql-results-url`: (string) URL to CodeQL results.
*   **Jobs:**
    *   **`security_scan_job`**:
        *   `name: GitHub Security Scans`
        *   `runs-on: ubuntu-latest`
        *   **Steps:** Checkout, Initialize CodeQL, Autobuild (if needed), Perform CodeQL Analysis, Set status and results URL.

## 4. Reusable Workflow: `reusable-static-code-analysis.yml`

*   **Filename:** `.github/workflows/reusable-static-code-analysis.yml`
*   **Purpose:** Performs static code analysis using tools like SonarQube or other linters.
*   **`on: workflow_call:`**
    *   **Inputs:**
        *   `solution-path`: (string, required) Path to solution/project files.
        *   `fail-on-issues`: (boolean, optional, default: `true`) Fail if quality gate fails or issues exceed threshold.
        *   `sonarqube-project-key`: (string, optional) SonarQube project key.
        *   `sonarqube-host-url`: (string, optional) SonarQube server URL.
        *   `sonarqube-organization`: (string, optional) SonarQube organization.
        *   `dotnet-version-for-scanner`: (string, optional, default: '6.0.x') .NET SDK for SonarScanner.
        *   `extra-scanner-args`: (string, optional) Additional scanner arguments.
    *   **Outputs:**
        *   `status`: ('success' or 'failure') Status of SAST execution.
        *   `analysis-url`: (string) URL to analysis report.
    *   **Secrets:**
        *   `SONAR_TOKEN`: (string, optional) SonarQube token. [7, 31, 35, 41, 42]
        *   `OTHER_SAST_TOOL_API_KEY`: (string, optional) Token for other SAST tools.
*   **Jobs:**
    *   **`sast_job`**:
        *   `name: Static Analysis`
        *   `runs-on: ubuntu-latest`
        *   **Steps:** Checkout (`fetch-depth: 0`), Setup .NET, Setup SonarScanner (or other tool), Run SonarScanner `begin`, Build project (may be needed by scanner), Run SonarScanner `end`, Set status and analysis URL, Check quality gate.

## 5. Reusable Workflow: `reusable-observability-hooks.yml`

*   **Filename:** `.github/workflows/reusable-observability-hooks.yml`
*   **Purpose:** Sends notifications about workflow status.
*   **`on: workflow_call:`**
    *   **Inputs:**
        *   `status`: (string, required) Calling workflow/job status.
        *   `workflow-name`: (string, required) Name of calling workflow.
        *   `run-url`: (string, required) URL to GitHub Actions run.
        *   `pr-number`: (string, optional) Pull request number.
        *   `commit-sha`: (string, optional) Commit SHA.
        *   `branch-name`: (string, optional) Branch name.
        *   `environment-name`: (string, optional) Environment name (for CD).
        *   `version-deployed`: (string, optional) Version deployed (for CD).
        *   `message-details`: (string, optional) Custom message details.
        *   `notification-channel`: (string, required) Target channel (e.g., 'slack', 'teams', 'email', 'github-pr-comment').
        *   `slack-mention-users-on-failure`: (string, optional) Slack user IDs to mention on failure.
    *   **Outputs:**
        *   `notification_sent_status`: ('success' or 'failure')
    *   **Secrets:**
        *   `SLACK_WEBHOOK_URL`: (string, optional) Slack webhook. [15, 21, 23, 24, 32]
        *   `TEAMS_WEBHOOK_URL`: (string, optional) Teams webhook.
        *   `EMAIL_SMTP_SERVER`, `EMAIL_SMTP_PORT`, `EMAIL_SMTP_USERNAME`, `EMAIL_SMTP_PASSWORD`, `EMAIL_TO_ADDRESS`, `EMAIL_FROM_ADDRESS`: (strings, optional) Email details.
        *   `GITHUB_TOKEN`: (string, optional) Required for 'github-pr-comment'.
*   **Jobs:**
    *   **`send_notification_job`**:
        *   `name: Send Notification`
        *   `runs-on: ubuntu-latest`
        *   **Steps:** Construct message, Conditional steps per `notification-channel` to send notification, Set status output.

