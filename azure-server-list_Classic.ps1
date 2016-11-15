#Powershell
##########################################
#
#  Author:
#    Johan Chassaing
#
#  License:
#    GPL
#
#  Dependencies:
#    Powershell, Azure cmdlet
#
#  Info: 
#    Print azure Classic instances information 
#      Subscription, name, powerstate, size,
#      ip private/public
#
#
##########################################

##########################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>. 
#
##########################################


##########################################
#
#               Variables
#
##########################################
$Log_Error = $FALSE
$Log_Info = $FALSE
$Log_Ok = $FALSE
$Log_Std = $FALSE
$Log_File = "log.txt"


##########################################
#
#               Functions
#
##########################################

# Error
function Echo_Error ($text) {
    Write-Host -ForegroundColor Red $text
    if ( $Log_Error ) {
        $text | Out-File -Append $Log_File
    }
}
# Information
function Echo_Info ($text) {
    Write-Host -ForegroundColor Yellow $text
    if ( $Log_Info ) {
        $text | Out-File -Append $Log_File
    }
}
# Good
function Echo_Ok ($text) {
    Write-Host -ForegroundColor Green $text
    if ( $Log_Ok ) {
        $text | Out-File -Append $Log_File 
    }
}
# Standard
function Echo_std ($text) {
    Write-Host $text
    if ( $Log_Std ) {
        $text | Out-File -Append $Log_File 
    }
}

##########################################
#
#                 Main
#
##########################################

# Check log path
if ( $Log_Error -or  $Log_Infos -or $Log_Ok -or $Log_Std ) { 
    $Log_Basedir = Split-Path $Log_File

    # check if Log_File is not empty and if basedir exists
    if  ( !( $Log_File ) -or ( $Log_Basedir -and !( Test-Path $Log_Basedir ) ) ) {
        $Log_Error = $FALSE
        Echo_Ko "[Error] Please check the Log path `"$Log_Basedir`""
        exit 1
    }
}

$Time=Get-Date


Echo_Std `n$Time

######################
# Account
######################

$Account = Get-AzureSubscription
if ( -Not $Account ){
    Echo_Error "[Error] - Get account information - Please add azure account with Add-AzureAccount"
    exit 1
}

Echo_Std "`nSubscriptions list: "
foreach ( $Subscription in $Account.SubscriptionName ) {

    Try {
        Select-AzureSubscription -Default $Subscription
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Set subscription failed - $Error_Message"
        exit 1
    }
    Echo_Info "   $Subscription"



    ######################
    # Instances
    ######################

    Try {
        $Instances = Get-AzureVM
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Get instances list - $Error_Message"
        exit 1
    }

    Echo_Std "`nInstances infos: "
    foreach ( $Instance in $Instances ) {

        Echo_Info " $Subscription;$($Instance.Name);$($Instance.PowerState);$($Instance.InstanceSize);$($Instance.IpAddress);$($Instance.PublicIPAddress)"

    }
}    
