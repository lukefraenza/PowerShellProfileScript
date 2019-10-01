Write-Host -ForegroundColor Green "Initializing custom functions and variables"
Write-Host -ForegroundColor Green "run Get-CustomFunctions to get list of functions"
Write-Host -ForegroundColor Green "run Get-ScriptVariables to get list of variables"

$thisScriptDir = (Split-Path -Path $profile)
# reference below variables
. $thisScriptDir/Variables.ps1
# [string]$ecapDir
# [string]$desktopDir
# [string]$ngrokDir
# [string]$ghostInspectorApiKey
# [string]$ngrokAuthToken


function Get-CustomFunctions() {
  Write-Host 'Start-FrontEnd'
  Write-Host 'Start-Backend'
  Write-Host 'Start-UnitTests'
  Write-Host 'Start-Ngrok'
  Write-Host 'Start-GiTests'
  Write-Host 'Remove-RemoteDeletedBranches'
  Write-Host 'Get-ScriptVariables'
  Write-Host '- - - - -'
  Write-Host 'Run `Get-Help <cmd> -full` for details on the above functions'
}

<#
  .Synopsis
    List script variables referenced in profile script
#>
function Get-ScriptVariables() {
  Write-Host '$ecapDir'
  Write-Host '$desktopDir'
  Write-Host '$ngrokDir'
  Write-Host '$ghostInspectorApiKey'
  Write-Host '$ngrokAuthToken'
}

<#
  .Synopsis
    Start the frontend.  Pass the -AOT switch to do an AOT build.
  .EXAMPLE
    Start-Frontend
  .EXAMPLE
    Start-Frontend -AOT
#>
function Start-Frontend {
  [CmdletBinding()]
  Param(
    # Do an AOT build
    [Parameter(Mandatory = $false)]
    [switch]
    $AOT
  )

  Write-Verbose "Changing directory to $ecapDir"
  Set-Location $ecapDir

  [string] $cmd = "npm run watch:frontend"
  if ($AOT -eq $true) {
    $cmd += ":aot"
  }

  Write-Debug "Running $cmd"
  Invoke-Expression "$cmd"
}

<#
  .Synopsis
    Start the backend
#>
function Start-Backend {
  [CmdletBinding()]
  Param()

  Write-Verbose "Changing directory to $ecapDir"
  Set-Location $ecapDir
  $cmd = "npm run watch:backend"
  Write-Debug "Running $cmd"
  Invoke-Expression $cmd
}

<#
  .Synopsis
    Run the frontend unit tests
  .DESCRIPTION
    Navigates to the ecap base directory and kicks off the frontend unit tests.
    You can pass a string to match against file names to limit the scope of the tests run.
  .EXAMPLE
    Start-UnitTests
  .EXAMPLE
    Start-UnitTests -MatchFiles filter-item.component
#>
function Start-UnitTests {
  [CmdletBinding()]
  Param(
    # comma-delimited string to match against spec file names
    [string] $MatchFiles
  )

  Write-Verbose "Changing directory to $ecapDir"
  Set-Location -Path $ecapDir
  $cmd = "npm run test:ng --matchFiles='$MatchFiles'";
  Write-Debug "Running $cmd"
  Invoke-Expression $cmd
}

<#
  .Synopsis
    Start up an ngrok process
  .DESCRIPTION
    Start up an ngrok process that watches port 5000.
    App must already be running on port 5000.
#>
function Start-Ngrok {
  [CmdletBinding()]
  Param()

  Write-Verbose "Changing directory to $ngrokDir"
  Set-Location -Path $ngrokDir
  Invoke-Expression ".\ngrok http 5000"
}

<#
  .Synopsis
    Run a Ghost Inspector Test/Suite and get the results
  .DESCRIPTION
    Start up an ngrok process, run a given Ghost Inspector test against it,
    display the results, and end the ngrok process.
    MAKE SURE THE APP IS RUNNING LOCALLY.
  .EXAMPLE
    Start-GiTests -TestId 5c94e01884b59763b47c63c1
  .EXAMPLE
    Start-GiTests -SuiteId 5cf6891f9ffa2f2438f04b31
#>
function Start-GiTests {
  [CmdletBinding()]
  Param(
    # Ghost Inspector test id
    [Parameter(Mandatory = $false)]
    [Alias("TID")]
    [string]
    $TestId,

    # Ghost Inspector suite id
    [Parameter(Mandatory = $false)]
    [Alias("SID")]
    [string]
    $SuiteId,

    # User-defined URL to run GI tests against
    [Parameter(Mandatory = $false)]
    [Alias("U")]
    [string]
    $URL
  )

  if ($PSBoundParameters.ContainsKey('TestId') -and $PSBoundParameters.ContainsKey('SuiteId')) {
    Write-Error "Please provide a TestId OR a SuiteID, not both"
    break
  }
  if (-not $PSBoundParameters.ContainsKey('TestId') -and -not $PSBoundParameters.ContainsKey('SuiteId')) {
    Write-Error "Please provide a TestId OR a SuiteID"
    break
  }

  Write-Verbose "Changing directory to $ecapDir"
  Write-Verbose "Running test $TestId"
  Set-Location $ecapDir

  [string] $cmd = "npm run test:ui -- -g $ghostInspectorApiKey"

  if ($PSBoundParameters.ContainsKey('URL')) {
    Write-Verbose "Running Ghost Inspector tests against user-provided URL: $URL"
    $cmd += " -u $URL"
  }
  else {
    Write-Verbose "Running Ghost Inspector tests using script-provided Ngrok session"
    $cmd += " -n $ngrokAuthToken"
  }
  if ($PSBoundParameters.ContainsKey('TestId')) {
    Write-Verbose "Running a single Ghost Inpector test: $TestId"
    $cmd += " -t $TestId"
  }
  elseif ($PSBoundParameters.ContainsKey('SuiteId')) {
    Write-Verbose "Running Ghost Inpector test suite: $SuiteId"
    $cmd += " -s $SuiteId"
  }
  Write-Debug "Running $cmd"
  Invoke-Expression $cmd
}


<#
  .Synopsis
    Get the last scheduled run results for all GI suites
  .EXAMPLE
    Get-GIResults
#>
function Get-GIResults {
  [CmdletBinding()]
  Param()
  Write-Verbose "Getting the last suite run results"
  Set-Location $ecapDir
  [string] $cmd = "node .\scripts\get-ghostInspectorResults.js -g $ghostInspectorApiKey -a"
  Invoke-Expression "$cmd"
}


function Remove-RemoteDeletedBranches {
  #Original bash command: git fetch -p -and for branch in `git branch -vv | grep ': gone]' | gawk '{print $1}'`; do git branch -D $branch; done

  #fetch and prune
  git fetch -p

  foreach ($branch in git branch -vv) {
    #get all deleted branches that aren't the active branch
    if (!$branch.StartsWith('*') -and $branch.Contains((': gone]'))) {
      #get the branch name
      $branchName = $branch.TrimStart(' ').Split(' ')[0]

      Try {
        git branch -D $branchName
      }
      Catch {
        Write-Error $_.Exception.Message
      }
    }
  }

  #list the remaining local branches
  Write-Host "Remaining branches:"
  git branch
}