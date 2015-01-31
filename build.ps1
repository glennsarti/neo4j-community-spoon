$ErrorActionPreference = "Stop"

[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null

# TODO
# Make it compile based on folder structure
# Download and install spoon if it doesn't exist
# Login to spoon if username/password supplied
# neo package - add a trigger to start the neo shell as well
# neo package - add plugins for shell tools
# Create a new 2.2.0-M02 package

#Write-Host "Login to spoon..."
#spoon login

$WorkingDir = "$($PSScriptRoot)\working"
$DownloadsDir = "$($PSScriptRoot)\downloads"
$PackagesSource = "$($PSScriptRoot)\src"

Function Invoke-Clean() {
  if (Test-Path -Path $WorkingDir) {
    Write-Host "Removing working..."
    Remove-Item -Path $WorkingDir -Confirm:$false -Recurse | Out-Null
  }
  Write-Host "Creating working..."
  New-Item -Path $WorkingDir -ItemType Directory | Out-Null
}

#---- BEGIN Package Provided params
. "$($PackagesSource)\neo4j-community-2.1.6\Package-Definition.ps1"
#---- END Package Provided params

# Run script to prep the build
$PackageFullName = "$($PackageName)-$($PackageVersion)"
$PackageDirectory = "$($PSScriptRoot)\src\$($PackageFullName)"
$SpoonPackage = "$($PackageName):$($PackageVersion)"
$SpoonScript = "$($PackageDirectory)\$($PackageFullName).me"

Invoke-Clean
$Downloads = $PackageDownloads + @{ "7za.exe" = "https://github.com/chocolatey/chocolatey/raw/master/src/tools/7za.exe"; }

$Downloads.Keys | ForEach-Object  {
  $fileName = "$($DownloadsDir)\$($_)"
  If (!(Test-Path -Path $fileName)) {
    Write-Host "Downloading $($_) from $($Downloads[$_]) ..." -ForegroundColor Green
    Invoke-WebRequest -OutFile $fileName -Uri $Downloads[$_]
  }
}

$Downloads.Keys | ForEach-Object  {
  $fileName = "$($DownloadsDir)\$($_)"
  Get-Item -Path "$($DownloadsDir)\$($_)" | % {
    $thisFile = $_
    switch ($thisFile.Extension.ToLower()) {
      ".zip" {
        Write-Host "Extracting $($thisFile.Name) ..." -ForegroundColor Green
        [System.IO.Compression.ZipFile]::ExtractToDirectory($fileName, "$($WorkingDir)\$($thisFile.BaseName)") 
      }
      ".exe" {
        Write-Host "Copying $($thisFile.Name) ..." -ForegroundColor Green
        Copy-Item -Path ($thisFile.Fullname) -Destination "$($WorkingDir)\$($thisFile.BaseName).exe" | Out-Null
      }
      ".gz" {
        Write-Host "Extracting (Part 1) $($thisFile.Name) ..." -ForegroundColor Green
        & "$($DownloadsDir)\7za.exe" x "$($thisFile.FullName)" "-o$($WorkingDir)" -y
        $tarFile = "$($WorkingDir)\$($thisFile.BaseName)"
        if (!(Test-Path -Path $tarFile)) { Throw "Failed to extract (part 1) $($thisFile.FullName)" }
        $theTarFile = Get-Item -Path $tarFile
        Write-Host "Extracting (Part 2) $($thisFile.Name) ..." -ForegroundColor Green
        & "$($DownloadsDir)\7za.exe" x "$($tarFile)" "-o$($WorkingDir)\$($theTarFile.BaseName)" -y
      }
      default { Write-Host "Ignoring $($thisFile.Name)" -ForegroundColor Green }
    }
  }
}

Write-Host "Copying support files..."
Get-ChildItem -Path "$PackageDirectory" | ? { $_.Extension.ToLower() -ne '.me'} | % {
  Write-Host "Copying $($_.BaseName)..." -ForegroundColor Green
  Copy-Item -Path $_.FullName -Destination "$($WorkingDir)" -Confirm:$false | Out-Null
}

Write-Host "Executing Spoon script ..." -ForegroundColor Green
If (!(Test-Path -Path $SpoonScript)) { Throw "Spoon script '$SpoonScript' was not found" }
spoon build "-n=$SpoonPackage" "$SpoonScript" --no-base --overwrite "--mount=$($WorkingDir)=C:\Working"

#-- End Script

