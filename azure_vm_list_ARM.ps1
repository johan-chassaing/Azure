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
#    Print azure Resource Manager (ARM) instances
#    List all your azure ARM virtual machines 
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

# output formating with automatic tag listing
# add empty column with "_empty_" field
$Output_Fields = "CloudProvider","Subscription","RessourceGroup","Name","_empty_"+$Tag_Filter+"PowerState","Location","AdminUsername","Size","Cores","Memory","private_ips","public_ips","public_ips_methods"

# To specify the tags in specific order fill in $Tag_Filter with tags' name
# To print tags, add the tags' name in the $output_fields
# Or let it empty for automatic listing

#$Tag_Filter = "info1","info2"
$Tag_Filter = @()

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
    $Account = Get-AzureRmContext -ErrorAction Stop
} Catch {
    $Error_Message = $_.Exception.message
    Echo_Error "[Error] - Get account information - $Error_Message"
    exit 1
}

#Select Subscription
foreach ( $Subscription in $Account.Subscription ) {
    $Subscription_Name = $($Subscription.SubscriptionName)

    Try {
        $AzureRmContext = Set-AzureRmContext -SubscriptionName "$Subscription_Name" -ErrorAction Stop
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Set subscription failed - $Error_Message"
        exit 1
    }
    Echo_Std "`nSubscription: "
    Echo_Info "$Subscription_Name"

    ######################
    # Instances
    ######################
    
    Try {
        $Instances = Get-AzureRmVm -Verbose -ErrorAction Stop
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Get instances list - $Error_Message"
        exit 1
    }

    Echo_Std "`nInstances infos: "
    # print fields
    Echo_Info "#$($Output_Fields -join ";")"
    
    foreach ( $Instance in $Instances ) {

        $CurrentInstance=@{}

        $CurrentInstance.Add("Subscription"   , $Subscription_Name)
        $CurrentInstance.Add("RessourceGroup" , $Instance.ResourceGroupName)
        $CurrentInstance.Add("Name"           , $Instance.Name)

        # Get Azure Instance Status
        Try {
            $VM_status = Get-AzureRmVM -ResourceGroupName $CurrentInstance.RessourceGroup -Name $CurrentInstance.Name -Status -ErrorAction Stop `                           | select -ExpandProperty statuses | Where-Object {$_.Code -match "PowerState"} `                           | select -ExpandProperty displaystatus
        } Catch {
            $Error_Message = $_.Exception.Message
            Echo_Error "[Error] - Get VM Status - $Error_Message"
            exit 1
        }

        $CurrentInstance.Add("PowerState"     , $VM_status)
        $CurrentInstance.Add("Location"       , $Instance.Location)
        $CurrentInstance.Add("AdminUsername"  , $Instance.OSProfile.AdminUsername)
        $CurrentInstance.Add("Size"           , $Instance.HardwareProfile.VmSize)

        if (-Not ($Tag_Filter) ) {
            # not filtered tags
            $Tag_Filter = @()
            $Instance.Tags.Keys | foreach {
                $CurrentInstance.Add("$_", $Instance.Tags[$_])
                $Tag_Filter += $_
            }

        } else {
            # filtered tags
            foreach ( $Tag in $Tag_Filter) {

                # if not exist return Not Defined
                if ( !( $Instance.Tags.ContainsKey($Tag) ) ) {
                    $CurrentInstance.Add("$Tag", "N/D")
                } else {
                    $CurrentInstance.Add("$Tag", "$($Instance.Tags.$Tag)")
                }
            } 
        }

        Try {
            $VM_Size = Get-AzureRmVMSize -Location $CurrentInstance.Location -ErrorAction Stop | Where-Object { $_.Name -eq "$($CurrentInstance.Size)" }
        } Catch {
            $Error_Message = $_.Exception.Message
            Echo_Error "[Error] - Get VM size list - $Error_Message"
            exit 1
        }
        $CurrentInstance.Add("Cores"  , $VM_Size.NumberOfCores)
        $CurrentInstance.Add("Memory" , $VM_Size.MemoryInMB)
        $CurrentInstance.Add("private_ips" , "")
        $CurrentInstance.Add("public_ips"  , "")
        $CurrentInstance.Add("public_ips_methods"  , "")

        foreach ( $Interface_Path in $($Instance.NetworkInterfaceIDs ))  {
            # Private ip
            $Interface_Path = $Interface_Path.Split("/")

            $Interface_Name = $Interface_Path[8]
            $Interface_ResourceGroup = $Interface_Path[4]
            
            Try {
                $Interface_Info = Get-AzureRmNetworkInterface -Name $Interface_Name -ResourceGroupName $Interface_ResourceGroup -ErrorAction Stop
            } Catch {
                $Error_Message = $_.Exception.message
                Echo_Error "[Error] - Get Private network interface information #$Interface_name - $Error_Message"
                exit 1
            }
            
            if (-Not $($CurrentInstance.private_ips) ){
                $separator=""
            }else{
                $separator=","
            }
            $CurrentInstance.private_ips += "$separator$($Interface_info.IpConfigurations[0].PrivateIpAddress)"
    
    
            # public ip
            $Interface_Path = $($Interface_info.IpConfigurations[0].PublicIpAddress.Id)
            $Interface_Path = $Interface_Path.Split("/")
           
            $Interface_Name = $Interface_Path[8]
            $Interface_ResourceGroup = $Interface_Path[4]
    
            Try {
                $Interface_Info = Get-AzureRmPublicIpAddress -Name $Interface_Name -ResourceGroupName $Interface_ResourceGroup -ErrorAction Stop
            } Catch {
                $Error_Message = $_.Exception.message
                Echo_Error "[Error] - Get Public network interface information #$Interface_name - $Error_Message"
                exit 1
            } 
    
            if (-Not $($CurrentInstance.public_ips) ){
                $separator=""
            }else{
                $separator=","
            }

            $CurrentInstance.public_ips_methods += "$separator$($Interface_info.PublicIpAllocationMethod)"
            $CurrentInstance.public_ips += "$separator$($Interface_info.IpAddress)"

        }

        # Generate output
        $output = ""

        foreach ( $field in $output_fields ){
            #echo "$field"
            # define separator
            if ( $output -eq "" ){
                $separator = ""
            } else {
                $separator = ";"
            }

            # define space
            if ( $field -eq "_empty_" ){
              $output += "$separator"
              #echo "-> _empty_"
            } elseif ( $field -eq "CloudProvider" ){
              $output += "$($separator)Azure-ARM"
              #echo "-> _empty_"
            } elseif ( $field -eq "" ){
              $output += "$($separator)empty tagname"
              #echo "-> empty"
            } elseif ( -Not $CurrentInstance.ContainsKey($field) ){
                #tag not defined
                $output += "$($separator)N/D"
                #echo "-> N/D"
            } else {
                $output += "$separator$($CurrentInstance[$field])"
                #echo "-> $($CurrentInstance[$field])"
            }
        }

        Echo_Ok $output
        $All_Instances += $output
    }
}
if ($Export_CSV) {
    $All_Instances | Out-File -Append "$Export_CSV_File"
}
