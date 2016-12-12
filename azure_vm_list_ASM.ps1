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
#    Print azure classic (ASM) instances
#    List all your azure ASM virtual machines 
#    information for each subscription 
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
$Output_Fields = "CloudProvider","Subscription","RessourceGroup","Name","_empty_","PowerState","Location","AdminUsername","Size","Cores","Memory","private_ips","public_ips","public_ips_methods"


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

$Account = Get-AzureSubscription -ErrorAction Stop
if ( -Not $Account ){
    Echo_Error "[Error] - Get account information - Please add azure account with Add-AzureAccount"
    exit 1
}

Echo_Std "`nSubscriptions list: "
foreach ( $Subscription in $Account.SubscriptionName ) {

    Try {
        $AzureSub = Select-AzureSubscription -SubscriptionName "$Subscription" -ErrorAction Stop
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Set subscription failed - $Error_Message"
        exit 1
    }
    Echo_Info "$Subscription"

    ######################
    # Instances
    ######################

    # Get Azure Vm list
    Try {
        $Instances = Get-AzureVM -Verbose -ErrorAction Stop
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Get instances list - $Error_Message"
        exit 1
    }

    # Get Azure Instances Size
    Try {
        $Role_Size = Get-AzureRoleSize -ErrorAction Stop
    } Catch {
        $Error_Message = $_.Exception.Message
        Echo_Error "[Error] - Get role size list - $Error_Message"
        exit 1
    }

    Echo_Std "`nInstances infos: "
    # print fields
    Echo_Info "#$($Output_Fields -join ";")"

    foreach ( $Instance in $Instances ) {
        $CurrentInstance=@{}

        $CurrentInstance.Add("Subscription"   , $Subscription)
        $CurrentInstance.Add("Name"           , $Instance.Name)
        $CurrentInstance.Add("PowerState"     , $Instance.PowerState)

        $CurrentInstance.Add("Size"           , $Instance.InstanceSize)
        $VM_Size = $Role_Size | Where-Object { $_.InstanceSize -eq "$($CurrentInstance["Size"])" }
        $CurrentInstance.Add("Cores"  , $VM_Size.Cores)
        $CurrentInstance.Add("Memory" , $VM_Size.MemoryInMb)

        # get Azure endpoints
        Try {
            $Vm_Endpoint = $Instance |  Get-AzureEndpoint -ErrorAction Stop
        } Catch {
            $Error_Message = $_.Exception.Message
            Echo_Error "[Error] - Get vm's endpoints - $Error_Message"
            exit 1
        }

        # private ip
        if (-Not $($CurrentInstance.private_ips) ){
            $separator=""
        }else{
            $separator=","
        }
        $CurrentInstance.private_ips += "$separator$($Instance.IpAddress)"

        # public ip
        if (-Not $($CurrentInstance.public_ips) ){
            $separator=""
        }else{
            $separator=","
        }

        $CurrentInstance.public_ips += "$separator$($Interface_info.IpAddress)"

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
              $output += "$($separator)Azure-ASM"
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
