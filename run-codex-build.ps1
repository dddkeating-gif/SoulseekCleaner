# run-codex-build.ps1
# Place this file in the root of your SoulseekCleaner repo (where the .sln lives)
# Then right-click it and choose "Run with PowerShell".

$ErrorActionPreference = "Continue"

Write-Host "=== SoulseekCleaner Codex build helper ===`n"

# Always work from the script's directory (repo root)
Set-Location -Path $PSScriptRoot

function Ensure-Command {
    param(
        [string]$Name,
        [string]$InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Warning "'$Name' is not installed."
        Write-Host ""
        Write-Host "Please install '$Name' using this hint:"
        Write-Host "  $InstallHint"
        Write-Host ""
        Read-Host "Press Enter AFTER you've installed '$Name' and reopened PowerShell"
    }
}

# 1) Check dotnet, node, npm
Ensure-Command "dotnet" "Download and install .NET 8 SDK (x64) from https://dotnet.microsoft.com/en-us/download/dotnet/8.0"
Ensure-Command "node"  "Download and install Node.js LTS from https://nodejs.org"
Ensure-Command "npm"   "Node.js should install npm automatically. If not, reinstall Node.js."

# 2) Install Codex CLI if missing
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Host "`nInstalling Codex CLI globally with npm..."
    npm install -g @openai/codex
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "npm install @openai/codex failed. Fix that, then run this script again."
        exit 1
    }
} else {
    Write-Host "Codex CLI already installed."
}

# 3) Make sure we're logged into Codex (sign in with ChatGPT / API) :contentReference[oaicite:0]{index=0}
Write-Host "`nChecking Codex login status..."
codex login status
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "You need to log into Codex once. A browser window will open."
    Write-Host "Use 'Sign in with ChatGPT' and finish the flow, then close the browser."
    Read-Host "Press Enter to start 'codex login'"
    codex login
    Write-Host "`nWhen Codex finishes logging in and returns to the prompt,"
    Read-Host "press Enter here to continue"
}

# 4) Create AGENTS.md with instructions (if it doesn't exist yet)
$agentsPath = Join-Path $PSScriptRoot "AGENTS.md"
if (-not (Test-Path $agentsPath)) {
    Write-Host "`nCreating AGENTS.md with default instructions..."
    @"
# SoulseekCleaner – Agent Instructions

Goal: Build and maintain a WPF (.NET 8) app called SoulseekCleaner that:

- Connects to Soulseek via the Soulseek.NET NuGet package
- Lets the user:
  - Enter a search term
  - Search Soulseek
  - View results with fuzzy match scores
  - Choose a file and download it
- After download:
  - Strip all metadata (ID3, Vorbis, FLAC, etc.) via TagLibSharp
  - Rename file to "Artist - Title.ext" where every word is capitalized
  - Move cleaned file to a user-defined output folder
- Provide a settings window stored in %AppData%/SoulseekCleaner/config.json

Build target:

- This command must succeed with no errors:
  dotnet publish SoulseekCleaner/SoulseekCleaner.csproj -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=true -o ./publish

You may edit code, update the workflow, and add tests as needed,
but keep behavior aligned with this spec.
"@ | Set-Content -Encoding UTF8 $agentsPath
} else {
    Write-Host "AGENTS.md already exists."
}

# 5) Ask Codex to fix the build and run dotnet publish until it passes. :contentReference[oaicite:1]{index=1}

$prompt = @"
Read AGENTS.md.

Your job is to make sure the command:

  dotnet publish SoulseekCleaner/SoulseekCleaner.csproj -c Release -r win-x64 -p:PublishSingleFile=true -p:SelfContained=true -o ./publish

succeeds on this machine.

Work in a loop:
- Run that publish command (and 'dotnet restore' if needed)
- Read any compiler or build errors
- Edit the code to fix them
- Re-run the publish until it succeeds with no errors.

When it passes, stop and summarize what you changed.
"@

Write-Host "`n=== Starting Codex in full-auto mode to fix and build SoulseekCleaner ==="
Write-Host "You can watch Codex work. If you ever want to stop it, press Ctrl+C."
Write-Host ""

# Full-auto lets Codex edit files and run commands inside the repo without asking every time.
codex --approval-mode full-auto "$prompt"
