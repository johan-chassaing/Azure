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
#    Print azure Resource Manager instances 
#    information for each subscription 
#    
#     Subscription, Resource Group, name, 
#     powerstate, location, tags, 
#     superuser,type, ip private/public
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

$Export_CSV = $TRUE
$Export_CSV_File = "azure_vm_list.csv"

# print static or dynamic public IP
$Print_Public_Ip_Method = $FALSE

# To specify the tags in specific order
# let empty for automatic listing
$Tag_Order = "info1","info2"
#$Tag_Order = ""


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
$All_Instances = @()
######################
# Account
######################

Try {
    $Account = Get-AzureRmContext
} Catch {
    $Error_Message = $_.Exception.message
    Echo_Error "[Error] - Get account information - $Error_Message"
    exit 1
}

#Select Subscription
foreach ( $Subscription in $Account.Subscription ) {
    $Subscription_Name = $($Subscription.SubscriptionName)

    Try {
        Set-AzureRmContext -SubscriptionName "$Subscription_Name"
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Set subscription failed - $Error_Message"
        exit 1
    }
    Echo_Info "$Subscription_Name"


    ######################
    # Instances
    ######################
    
    Try {
        $Instances = Get-AzureRmVm
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Get instances list - $Error_Message"
        exit 1
    }
    
    Echo_Std "`nInstances infos: "
    Echo_Info "#SubscriptionName;ResourceGroupName;Name;PowerState;Location;TagKey:tagValue;AdminUsername;Size;CPU;MEM;Private_IP;Public_IPs"
    
    foreach ( $Instance in $Instances ) {

        $Inst_Location = $($Instance.Location)
        $Inst_Size = $($Instance.HardwareProfile.VmSize)

        # Manage tags
        $Inst_Tags_String = "" 
        $Inst_Tags = $($Instance.Tags)
    
        if (-Not ($Tag_Order) ) {
            # not ordered tags
            $Inst_Tags_String = ( ( $Inst_Tags.Keys | foreach { "$_`:$($Inst_Tags[$_])" }) -join ";" )
        } else {
            # ordered tags 
            foreach ( $Tag in $Tag_Order) {
                # if not exist return Not Defined
                if ( !( $Inst_Tags.ContainsKey($tag) ) ) {
                    $Tag_value = "N/D"
                } else { 
                    $Tag_value = $Inst_Tags.$Tag
                }
                # set tag separator
                if (-Not ($Inst_Tags_String)){
                    $separator=""
                }else{
                    $separator=";"
                }
                $Inst_Tags_String += "$separator$($Tag):$($Tag_value)"
            } 
        }

        # Get Azure Instance Size
        Try {
            $VM_Size = Get-AzureRmVMSize -Location $Inst_Location | Where-Object { $_.Name -eq "$Inst_Size" }
        } Catch {
            $Error_Message = $_.Exception.Message
            Echo_Error "[Error] - Get VM size list - $Error_Message"
            exit 1
        }
        $Inst_CPU = $VM_Size.NumberOfCores
        $Inst_MEM = $VM_Size.MemoryInMB

        # Manage IP addresses
        #
        $Inst_Private_Ips = "" 
        $Inst_Public_Ips = "" 
        foreach ( $Interface_Path in $($Instance.NetworkInterfaceIDs ))  {
            # Private ip
            $Interface_Path = $Interface_Path.Split("/")
         
            $Interface_Name = $Interface_Path[8]
            $Interface_ResourceGroup = $Interface_Path[4]
            
            Try {
                $Interface_Info = Get-AzureRmNetworkInterface -Name $Interface_Name -ResourceGroupName $Interface_ResourceGroup
            } Catch {
                $Error_Message = $_.Exception.message
                Echo_Error "[Error] - Get Network interface information #$Interface_name - $Error_Message"
                exit 1
            }
            
            if (-Not ($Inst_Private_Ips)){
                $separator=""
            }else{
                $separator=","
            }
            $Inst_Private_Ips += "$separator$($Interface_info.IpConfigurations[0].PrivateIpAddress)"
    
    
            # public ip
            $Interface_Path = $($Interface_info.IpConfigurations[0].PublicIpAddress.Id)
            $Interface_Path = $Interface_Path.Split("/")
           
            $Interface_Name = $Interface_Path[8]
            $Interface_ResourceGroup = $Interface_Path[4]
    
            Try {
                $Interface_Info = Get-AzureRmPublicIpAddress -Name $Interface_Name -ResourceGroupName $Interface_ResourceGroup
            } Catch {
                $Error_Message = $_.Exception.message
                Echo_Error "[Error] - Get Network interface information #$Interface_name - $Error_Message"
                exit 1
            } 
    
            if (-Not ($Inst_Public_Ips)){
                $separator=""
            }else{
                $separator=","
            }
            if (-Not ($Print_Public_Ip_Method)){
                $Interface_Method=""
            } else {
                $Interface_Method="$($Interface_info.PublicIpAllocationMethod):"
            }
    
            $Inst_Public_Ips += "$separator$Interface_Method$($Interface_info.IpAddress)"
                 
        }
       
       $CurrentInstance="$Subscription_Name;$($Instance.ResourceGroupName);$($Instance.Name);$($Instance.PowerState);$Inst_Location;$($Inst_Tags_String);$($Instance.OSProfile.AdminUsername);$Inst_Size;$Inst_CPU;$Inst_MEM;$Inst_Private_Ips;$Inst_Public_Ips"
       Echo_Ok $CurrentInstance
       $All_Instances += $CurrentInstance
    }
}
if ($Export_CSV) {
    $All_Instances | Out-File -Append "$Export_CSV_File"
}