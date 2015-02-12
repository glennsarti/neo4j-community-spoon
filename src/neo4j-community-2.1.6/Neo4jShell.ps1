Param()
$ErrorActionPreference = "Stop"

function Exit-WithCode
{
  param
  (
    $exitcode
  )

  $host.SetShouldExit($exitcode)
  Exit
}
function Get-ScriptDirectory
{
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  $Global:ScriptDirectory = (Split-Path ($Invocation.MyCommand.Path))
  Write-Output $Global:ScriptDirectory
}
[void] (Get-ScriptDirectory)

$baseDir = Split-Path -Path $Global:ScriptDirectory -Parent  

$JavaCMD = 'java'
$RepoPath = Join-Path  -Path $baseDir -ChildPath 'lib'
$ClassPath = ''

Get-ChildItem -Path $RepoPath | ? { $_.Extension -eq '.jar'} | % {
  $ClassPath += "`"$($_.FullName)`";"
}
if ($ClassPath.Length -gt 0) { $ClassPath = $ClassPath.SubString(0, $ClassPath.Length-1) } # Strip the trailing semicolon if needed

$ShellArgs = @()
if ($Env:JAVA_OPTS -ne $null) { $ShellArgs += $Env:JAVA_OPTS }
if ($Env:EXTRA_JVM_ARGUMENTS -ne $null) { $ShellArgs += $Env:EXTRA_JVM_ARGUMENTS }
$ShellArgs += @("-classpath $($Env:CLASSPATH_PREFIX);$ClassPath","-Dapp.name=`"neo4j-shell`"","-Dapp.repo=`"$($RepoPath)`"","-Dbasedir=`"$baseDir`"","org.neo4j.shell.StartClient")
# Add unbounded command line arguments
$ShellArgs += $args

$result = (Start-Process -FilePath $JavaCMD -ArgumentList $ShellArgs -Wait -NoNewWindow -PassThru)

Write-Host "Exit code $($result.ExitCode)"
Exit-WithCode $result.ExitCode