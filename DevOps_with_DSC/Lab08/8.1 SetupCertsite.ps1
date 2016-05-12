Install-Module xWebAdministration -RequiredVersion 1.10.0.0

$ConfigurationData = @{   
    AllNodes = @(       
        @{     
            NodeName                    = "$env:COMPUTERNAME"
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
            Role                        = "CertificateSite"
            PFXURL                      = "pfx.filemilk.net"
            PFXIP                       = "192.168.1.2"
            PFXPATH                     = "C:\PFXSite"
        } 
    )  
}

Configuration Roles
{
    param 
    (
        [Parameter(Mandatory)] 
        [pscredential]$Credential
    ) 

    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration
    Import-DscResource -ModuleName xDnsServer

    Node $AllNodes.Where{$_.Role -eq "CertificateSite"}.Nodename
    {
        
        xDnsServerADZone AddPFXZone
        {
            Name             = $Node.PFXURL
            DynamicUpdate    = "Secure"
            ReplicationScope = "Forest"
            Credential       = $Credential
            Ensure           = "Present"
        }

        xDnsRecord AddPFXSameAsParentRecord
        {
            Name      = "."
            Target    = $Node.PFXIP
            Zone      = $Node.PFXURL
            Type      = "ARecord"
            Ensure    = "Present"
            DependsOn = "[xDnsServerADZone]AddPFXZone"
        }

        File PFXSite
        {
           Ensure          = "Present"
           DestinationPath = $Node.PFXPATH
           Type            = "Directory"
        }

        WindowsFeature InstallIISConsole
        {
            Ensure = "Present"
            Name   = "Web-Mgmt-Console"
        }
             
        xWebsite PFXWebsite 
        { 
            Ensure       = "Present" 
            Name         = "PFX" 
            State        = "Started" 
            PhysicalPath = $Node.PFXPATH
            BindingInfo  = MSFT_xWebBindingInformation 
                         {
                             Protocol = "HTTP"
                             Port     = 80
                             HostName = $Node.PFXURL
                         }
        }
        
    }
}

# Create MOF job
Roles -OutputPath $env:TEMP -ConfigurationData $ConfigurationData -Credential (Get-Credential -UserName cfg\administrator -Message "Domain Admin Credential") 

# Run the MOF job
Start-DscConfiguration -Path $env:TEMP -Wait -Force -Verbose