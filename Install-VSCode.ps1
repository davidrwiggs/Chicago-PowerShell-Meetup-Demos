#region WMP Legal Banner
<####################################################################################
 # Copyright (c) 2019, West Monroe Partners
 # All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without modification,
 # are permitted provided that the following conditions are met:
 #
 #   Redistributions of source code must retain the above copyright notice, this
 #   list of conditions and the following disclaimer.
 #
 #   Redistributions in binary form must reproduce the above copyright notice, this
 #   list of conditions and the following disclaimer in the documentation and/or
 #   other materials provided with the distribution.
 #
 #   Neither the name of West Monroe Partners nor the names of its
 #   contributors may be used to endorse or promote products derived from
 #   this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 # ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 # WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 # DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 # ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 # (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 # LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 # ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#####################################################################################>
#endregion

#region Get-Help
#####################################################################################
################                    Begin Get-Help                   ################
<####################################################################################
.SYNOPSIS
This script completes and installation of Visual Studio Code and completes
configuration for integration with PowerShell and TFS Online. The script requires
elevated access and an internet connection to install applications and complete
configurations. The script will utilize Chocolatey to simplify installation of git,
Java, puTTY, and Visual Studio Code. The PowerShell and TFS extensions are installed
for Visual Studio Code. The script creates ~\My Documents\Azure DevOps directory to
host the clone of a given repository.

.DESCRIPTION
A script that installs and configures Visual Studio Code for use with a
repository hosted on Azure DevOps. Note that if Chocolatey is not installed, it
will be downloaded and installed with the default configuration

.PARAMETER
No parameters are used in this script.

.EXAMPLE
> .\Install-VSCode.ps1

.NOTES
Author     : David Wiggs - dwiggs@wmp.com
Requires   : Elevated PowerShell session to install applications and implement
             configuration changes. Note that this script has only been tested
             on a Windows 10 client.
#####################################################################################>
#################                    End Get-Help                   #################
#####################################################################################
#endregion

#region Main Script Routine
#####################################################################################
#################                    Begin script                   #################
#####################################################################################

#region Code to Run as Local Admin
#####################################################################################
#################    Begin code to be run as local administrator    #################
#####################################################################################

# Check to see if Chocolatey is installed
if ($null -eq (Get-Command "choco.exe" -ErrorAction SilentlyContinue))
{
    # Session must be able to run scripts
    Set-ExecutionPolicy Bypass -Scope Process -Force

    # Download and run Chocolatey installation script
    $downloadString = 'https://chocolatey.org/install.ps1'
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("$downloadString"))
}

# Install git using Chocolatey
choco install git -y --no-progress

# Install java using Chocolatey
choco install javaruntime -y --no-progress

# Install VSCode using Chocolatey
choco install visualstudiocode -y --no-progress

# Get latest version information
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$json = ConvertFrom-Json (Invoke-WebRequest -Uri https://api.github.com/repos/Microsoft/team-explorer-everywhere/releases/latest -UseBasicParsing)

# Download latest version
$downloadURL = $json.assets.'browser_download_url'[0]
$TEECLCversion = $downloadURL.Split('/')[-1]
Invoke-WebRequest -Uri "$downloadURL" -OutFile "$env:ProgramFiles\Microsoft VS Code\$TEECLCversion"

# Unzip TEE-CLC files
Add-Type -Assembly "System.IO.Compression.FileSystem"
if ($TEECLCversion.Substring($TEECLCversion.Length - (".zip").Length, (".zip").Length) -eq ".zip")
{
    # $TEECLCversion ends in ".zip" as expected
    # Remove the .zip extension and store the string as the folder name
    $strTeamExplorerEverywhereFolderName = $TEECLCversion.Substring(0, $TEECLCversion.Length - (".zip").Length)
    if (Test-Path ($env:ProgramFiles + "\Microsoft VS Code\" + $strTeamExplorerEverywhereFolderName))
    {
        # Folder already exists
        Remove-Item ($env:ProgramFiles + "\Microsoft VS Code\" + $strTeamExplorerEverywhereFolderName) -Recurse
    }
}

[IO.Compression.ZipFile]::ExtractToDirectory(($env:ProgramFiles + "\Microsoft VS Code\" + $TEECLCversion), ($env:ProgramFiles + "\Microsoft VS Code"))

#####################################################################################
#################     End code to be run as local administrator     #################
#####################################################################################
#endregion

#region Code to Run as Each Account That is Using VS Code Day-to-Day
#####################################################################################
#################   Begin code to be run as account that is using   #################
#################                 VS Code day-to-day                #################
#####################################################################################

# Begin setting environment variables
# Get current values in the user PATH variable
$environmentVariableTarget = [System.EnvironmentVariableTarget]::User
$userPath = [System.Environment]::GetEnvironmentVariable("PATH",$environmentVariableTarget)

# Verify that git is installed in the default location
# Add git to user environment PATH string
if ((Test-Path -Path "$env:LOCALAPPDATA\Programs\Git\cmd") -and $userPath -notcontains "$env:LOCALAPPDATA\Programs\Git\cmd")
{
    $userPath = $userPath + ";$env:LOCALAPPDATA\Programs\Git\cmd"
} `
else `
{
    $gitPath = (Get-ChildItem C:\ -recurse -Directory -Force -ErrorAction SilentlyContinue | Where-Object {$_.FullName -like "*Git\cmd"}).FullName
    $userPath = $userPath + ";$gitPath"
}

# Add VSCode to user environment PATH string
if ((Test-Path -Path "$env:ProgramFiles\Microsoft VS Code\bin") -and $userpath -notcontains "$env:ProgramFiles\Microsoft VS Code\bin")
{
    $userpath = $userpath + ";$env:ProgramFiles\Microsoft VS Code\bin"
}

# Add Java to user environment PATH string
if ($userpath -notcontains "$env:ProgramFiles\Microsoft VS Code;%JAVA_HOME\bin")
{
    $userpath = $userpath + ";$env:ProgramFiles\Microsoft VS Code;%JAVA_HOME\bin"
}

# Set the PATH variable
[System.Environment]::SetEnvironmentVariable("PATH","$userpath",$EnvironmentVariableTarget)

# Add java to user environment
$jreVersion = Get-ChildItem -Path "${env:ProgramFiles}\Java" | `
    Sort-Object -Descending | `
    Select-Object -First 1 -ExpandProperty Name
$javaDirectory = $env:ProgramFiles + "\Java\" + $jreVersion

if (!(Test-Path env:\JAVA_HOME))
{
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME","$javaDirectory",$EnvironmentVariableTarget)
}

if (!(Test-Path env:\JDK_HOME))
{
    [System.Environment]::SetEnvironmentVariable("JDK_HOME","%JAVA_HOME%",$EnvironmentVariableTarget)
}

if (!(Test-Path env:\JRE_HOME))
{
    [System.Environment]::SetEnvironmentVariable("JRE_HOME","%JAVA_HOME%\jre",$EnvironmentVariableTarget)
}

if (!(Test-Path env:\_JAVA_OPTIONS))
{
    [System.Environment]::SetEnvironmentVariable("_JAVA_OPTIONS","-Xmx512M",$EnvironmentVariableTarget)
}

# Refresh environment PATH variable for the current session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install PowerShell and TFS extensions
# Silently continue on error to suppress error about not being able to store machine ID - this error does not impact functionality
code --install-extension ms-vscode.powershell -ErrorAction SilentlyContinue
code --install-extension ms-vsts.team

# Apply user settings for TFS integration
$jsonSettings = "$env:APPDATA\Code\User\settings.json"

if (Test-Path -Path "$jsonSettings")
{
    # File exists
    $filejson = Get-Content -Raw -Path $jsonSettings | ConvertFrom-Json
    if (($filejson | Get-Member).Name -Contains "tfvc.location")
    # Setting "tfvc.location" exsists, make sure that the propert path is specified
    {
        $filejson."tfvc.location" = "$env:ProgramFiles\Microsoft VS Code\$TEECLCversion\tf.cmd"
    } `
    else `
    {
        $filejson | Add-Member -MemberType NoteProperty -Name 'tfvc.location' -Value "$env:ProgramFiles\Microsoft VS Code\$TEECLCversion\tf.cmd"
    }
    $filejson | ConvertTo-Json | Out-File $jsonSettings -Encoding utf8 -Force
} `
else `
{
    $filejson = New-Object -TypeName psobject
    $filejson | Add-Member -MemberType NoteProperty -Name 'tfvc.location' -Value "$env:ProgramFiles\Microsoft VS Code\tf.cmd"
    $filejson | ConvertTo-Json | Out-File $jsonSettings -Encoding utf8 -Force
}

# Create local folder for use with TFS in %USERPROFILE%\My Documents
if (Test-Path -Path (([Environment]::GetFolderPath("mydocuments")) + "\Azure DevOps"))
{
    $ADOdirectory = Get-Item -Path (([Environment]::GetFolderPath("mydocuments")) + "\Azure DevOps")
} `
else `
{
    $ADOdirectory = New-Item -path ([Environment]::GetFolderPath("mydocuments")) -name "Azure DevOps" -itemtype directory
}

# Clone repository to project directory
Set-Location $ADOdirectory
$projectName = Read-Host 'Please enter the name of the project'
Write-Host "Note that the following directory will be created:`n$ADOdirectory\$projectName"
$cloneURL = Read-Host 'Please enter the url of the VSTS project to clone'
git clone  "$cloneURL" "$projectName" -q

# Open VS Code in local workspace and display cloned directory
$localWorkspace = "$ADOdirectory\$projectName"
Write-Host 'Now opening Visual Studio Code...'
code -n $localWorkspace

#####################################################################################
#################    End code to be run as account that is using    #################
#################                 VS Code day-to-day                #################
#####################################################################################
#endregion

#####################################################################################
##################                    End script                   ##################
#####################################################################################
#endregion
# SIG # Begin signature block
# MIIdRAYJKoZIhvcNAQcCoIIdNTCCHTECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUtp4zYY9awPqPvaIfYtL5RuEs
# aL6gggpzMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFOzCC
# BCOgAwIBAgIQAVQeaFqgfudoEzeTfKt6UDANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTE4MDMyOTAwMDAwMFoXDTE5MDQwMjEyMDAwMFoweDEL
# MAkGA1UEBhMCVVMxETAPBgNVBAgTCElsbGlub2lzMRAwDgYDVQQHEwdDaGljYWdv
# MSEwHwYDVQQKExhXZXN0IE1vbnJvZSBQYXJ0bmVycyBMTEMxITAfBgNVBAMTGFdl
# c3QgTW9ucm9lIFBhcnRuZXJzIExMQzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAKTau7SBOUeEBIwB+Re1o00N2usHWO0V12ZtUryyGvEUkVfecS43NZsi
# z3yc20MooxZSnYI2/gZ7OrqajG1faVkf/QfIH21AZiKuEUnJKITLGCcKasFzs8cx
# F0+AOA/G3VcmUoBwQrScf8PCNiYG0SmYaYHNrVpflpJPRV+ApvRcRPfZP98rQPIn
# LQB4JNy6FsqxxJLPXj58cVHaQzouxyPveWuXN8gfJ2RMr2eEp/ixA8jwk5fUmOA0
# jHx2BEFbUdn3+bLEeECGNvU2zzY/No8MskKUc645YQxjICv5FQv5EBtL7mZwJmWi
# 9WdkV8fjPLCN0J/LX2NeSQEAyEH97jkCAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaA
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBT7188DJUr/K/2zuyIYLeWu
# FzF7bTAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0f
# BHAwbjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJl
# ZC1jcy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEy
# LWFzc3VyZWQtY3MtZzEuY3JsMEwGA1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYI
# KwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQB
# MIGEBggrBgEFBQcBAQR4MHYwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBOBggrBgEFBQcwAoZCaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB
# /wQCMAAwDQYJKoZIhvcNAQELBQADggEBANYcJTJ2O18jr5IE1f5e/PQZJedBCtnC
# sE6jXk5CeTy8Eiqqi3nG/Qiga1LIIshhs7AWA5JT77ujNGrS285s23UMm4fnP7Q1
# WFsmeJGEJX9857nuv1b+ZZNjj1c51em2ohZa4BCyyvilN255cdXlbXm8pWVZdnpC
# zZ21AQi8lQUl8CCaY2Z0oA7WR+/YwfvfRUenXymkONpIjVQz7LqZOoY5vi20AA6P
# lNcTQfIDaPGlyjgeiKpEwpycLUQp7jfOKON4BjnJfao/tZHmuqklyvTHuF4pX8F3
# 3ayu3jPnKK/aWCNuIkKFeD55vNE0myo69gWs4Wby5cP+ZK8oftxsEToxghI7MIIS
# NwIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEy
# IEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBAhABVB5oWqB+52gTN5N8q3pQMAkG
# BSsOAwIaBQCgcDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0B
# CQQxFgQUpxZxcFvm/pBwEt+8kUNjq6krzmYwDQYJKoZIhvcNAQEBBQAEggEAk1Lo
# T1LUwx/mpVlpPpD9dZEpTb+yOd8zTAWdfv0AWQbg2O8x7j5lBLIEZqtq54fv17ey
# C0uzrqhXk/2HEHc2Yru8tcYeVV6Bo/M6NKiZMe/++igaGsJrQADl1auUc4pwjvDY
# L+JuZ7y5X5AHDOgX8vDMyiYkBYxJupG7lifNfKHwEuSAtc2G1nhBsrXn6zM30iJP
# 66YdGza0A6ZcNc1zPjPOW0ZDSSo6ERoKqy5aJEZSWnjLMXPUMHIEiXupczSXqkgB
# OT5ocoYHQoXpveKgc1yF1bJUH2u3Jh9EZcBqCdXfZT7SJfCpPHMqDgLaUeUQfa47
# KYyTiyOgSL3HR6wBxKGCEBcwghATBgorBgEEAYI3AwMBMYIQAzCCD/8GCSqGSIb3
# DQEHAqCCD/Awgg/sAgEDMQswCQYFKw4DAhoFADBnBgsqhkiG9w0BCRABBKBYBFYw
# VAIBAQYJYIZIAYb9bAcBMCEwCQYFKw4DAhoFAAQUOz5sx+weUcvMLeeyPdjZk5Db
# oOwCECT6963Y7mrAsEHfyTNgO0QYDzIwMTkwMjA2MTk1ODMxWqCCDT8wggZqMIIF
# UqADAgECAhADAZoCOv9YsWvW1ermF/BmMA0GCSqGSIb3DQEBBQUAMGIxCzAJBgNV
# BAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdp
# Y2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMTAeFw0x
# NDEwMjIwMDAwMDBaFw0yNDEwMjIwMDAwMDBaMEcxCzAJBgNVBAYTAlVTMREwDwYD
# VQQKEwhEaWdpQ2VydDElMCMGA1UEAxMcRGlnaUNlcnQgVGltZXN0YW1wIFJlc3Bv
# bmRlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKNkXfx8s+CCNeDg
# 9sYq5kl1O8xu4FOpnx9kWeZ8a39rjJ1V+JLjntVaY1sCSVDZg85vZu7dy4XpX6X5
# 1Id0iEQ7Gcnl9ZGfxhQ5rCTqqEsskYnMXij0ZLZQt/USs3OWCmejvmGfrvP9Enh1
# DqZbFP1FI46GRFV9GIYFjFWHeUhG98oOjafeTl/iqLYtWQJhiGFyGGi5uHzu5uc0
# LzF3gTAfuzYBje8n4/ea8EwxZI3j6/oZh6h+z+yMDDZbesF6uHjHyQYuRhDIjegE
# YNu8c3T6Ttj+qkDxss5wRoPp2kChWTrZFQlXmVYwk/PJYczQCMxr7GJCkawCwO+k
# 8IkRj3cCAwEAAaOCAzUwggMxMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIIBvwYDVR0gBIIBtjCCAbIwggGhBglg
# hkgBhv1sBwEwggGSMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBm
# ACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABp
# AHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAg
# AEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAg
# AFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAg
# AHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBu
# AGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBp
# AG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTAfBgNV
# HSMEGDAWgBQVABIrE5iymQftHt+ivlcNK2cCzTAdBgNVHQ4EFgQUYVpNJLZJMp1K
# Knkag0v0HonByn0wfQYDVR0fBHYwdDA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5jcmwwOKA2oDSGMmh0dHA6Ly9j
# cmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMHcGCCsG
# AQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRBc3N1cmVkSURDQS0xLmNydDANBgkqhkiG9w0BAQUFAAOCAQEAnSV+GzNNsiaB
# XJuGziMgD4CH5Yj//7HUaiwx7ToXGXEXzakbvFoWOQCd42yE5FpA+94GAYw3+pux
# nSR+/iCkV61bt5qwYCbqaVchXTQvH3Gwg5QZBWs1kBCge5fH9j/n4hFBpr1i2fAn
# PTgdKG86Ugnw7HBi02JLsOBzppLA044x2C/jbRcTBu7kA7YUq/OPQ6dxnSHdFMoV
# XZJB2vkPgdGZdA0mxA5/G7X1oPHGdwYoFenYk+VVFvC7Cqsc21xIJ2bIo4sKHOWV
# 2q7ELlmgYd3a822iYemKC23sEhi991VUQAOSK2vCUcIKSK+w1G7g9BQKOhvjjz3K
# r2qNe9zYRDCCBs0wggW1oAMCAQICEAb9+QOWA63qAArrPye7uhswDQYJKoZIhvcN
# AQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFowYjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBDQS0x
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBzQHDS
# nlZUXKnE0kEGj8kz/E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r7a2w
# cTHrzzpADEZNk+yLejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD/6b3
# +6LNb3Mj/qxWBZDwMiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z8rwM
# K5nQxl0SQoHhg26Ccz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2zkBd
# XPao8S+v7Iki8msYZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9BwSi
# CQIDAQABo4IDejCCA3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsGAQUF
# BwMBBggrBgEFBQcDAgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCCAdIG
# A1UdIASCAckwggHFMIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEWLmh0
# dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFk
# BggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBz
# ACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBz
# ACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBD
# AGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBp
# AG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBo
# ACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBl
# ACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAg
# AHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQIMAYB
# Af8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4
# oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJv
# b3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+Vw0r
# ZwLNMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEB
# BQUAA4IBAQBGUD7Jtygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKyXGGi
# nJXDUOSCuSPRujqGcq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+erYs37
# iy2QwsDStZS9Xk+xBdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+cdkvt
# X8JLFuRLcEwAiR78xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeSDY2x
# aYxP+1ngIw/Sqq4AfO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGtSTGD
# R5V3cdyxG0tLHBCcdxTBnU8vWpUIKRAmMYICLDCCAigCAQEwdjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTECEAMBmgI6
# /1ixa9bV6uYX8GYwCQYFKw4DAhoFAKCBjDAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTE5MDIwNjE5NTgzMVowIwYJKoZIhvcNAQkE
# MRYEFF1JyoHXnJfeE5FZ3dZJcIGCmcuSMCsGCyqGSIb3DQEJEAIMMRwwGjAYMBYE
# FGFNJx2RAuMBaYIkh/3l3gCjUrAdMA0GCSqGSIb3DQEBAQUABIIBAI31HnFdHX6d
# 52x+m8bmyP0Gw8Ap03hjtb7ZNQfsLt76v4ygArHPaYKBKR3BORMvD7Hui6xUuXnZ
# kjxP31wh0DepkTLDm2ha+pjpaXPm5qsaS5/iK7lHT81J0dptp4IYNIOpx2edEi24
# //x5o0wM6gI3Cooy9dFu5qL+ihgHwYaDkg8RngtIUQqYuMER5K73YJzvx7PQ/BmP
# G3YSknaJpbi7nUQT75Ukv7Tn92IgJ0ki1Z2CnlBkUXV7vrdofQ66S9i/G9pqSMSc
# CkZbm/EeoX+PRQDDqjvHLoZ4iT/+TKY72Tb1jDurBs+rFiJHXf5EX/Muugb7wQvl
# c7h8EMyW/bI=
# SIG # End signature block
