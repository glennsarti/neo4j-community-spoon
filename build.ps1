$ErrorActionPreference = "Stop"

[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null

# TODO
# Download and install spoon if it doesn't exist
# Login to spoon if username/password supplied
# neo package - add a trigger to start the neo shell as well
# neo package - add plugins for shell tools
# Create a new 2.2.0-M02 package

# Check if spoon is installed...

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

Get-ChildItem -Path $PackagesSource | % {
  $pkgDefn = Join-Path -Path ($_.Fullname) -ChildPath 'Package-Definition.ps1'
  if (Test-Path -Path $pkgDefn) {
    Write-Host "Found package definition file '$($pkgDefn)'" -ForegroundColor Cyan

    # Load the package definition
    . "$pkgDefn"
    
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
  }
}