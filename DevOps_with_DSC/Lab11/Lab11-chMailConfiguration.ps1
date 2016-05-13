$ConfigurationData = @{   
    AllNodes = @(        
                @{     
                    NodeName                    = "$env:COMPUTERNAME"                          
                    PSDscAllowPlainTextPassword = $true
                    PSDscAllowDomainUser        = $true
                } 
            )  
    } 

Configuration CustomResource
{
    param 
    (
        
        [Parameter(Mandatory=$true)]
        [String]$Ensure,
 
        [Parameter(Mandatory=$true)]
        [String]$DomainName,

        [Parameter(Mandatory=$true)]
        [String]$AccountAddress,
                
        [Parameter(Mandatory=$true)]
        [String]$AccountADUserName,
        
        [Parameter(Mandatory=$true)]
        [String]$AccountADDomain,

        [Parameter(Mandatory=$true)]
        [String]$AdminUsername,

        [Parameter(Mandatory=$true)]
        [String]$AdminPassword

    ) 

    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource –ModuleName chMail

    Node "$env:COMPUTERNAME" 
    {  
        chMailAccounting CreateDomainAndAccount
        {
                Ensure            = $Ensure
                DomainName        = $DomainName
                AccountAddress    = $AccountAddress
                AccountADUserName = $AccountADUserName
                AccountADDomain   = $AccountADDomain
                AdminUsername     = $AdminUsername
                AdminPassword     = $AdminPassword
               
        }
        
    }
}

$Params = @{
    Ensure            = 'Present'
    DomainName        = 'filemilk.net'
    AccountAddress    = 'administrator@filemilk.net'
    AccountADUserName = 'administrator'
    AccountADDomain   = 'cfg.filemilk.net'
    AdminUsername     = 'administrator'
    AdminPassword     = 'P@ssw0rd'
    OutputPath        = $env:TEMP
    ConfigurationData = $ConfigurationData
}
# Create MOF job
CustomResource @Params

# Run the MOF job
Start-DscConfiguration -Path $env:TEMP -Wait -Force -Verbose
