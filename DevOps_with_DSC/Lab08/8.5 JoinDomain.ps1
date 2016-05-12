# Install the xNetworking and xComputerManagement module, restart ISE if necessary
Install-Module xNetworking         -RequiredVersion 2.8.0.0
Install-Module xComputerManagement -RequiredVersion 1.5.0.0

# Configuration data block
$ConfigurationData = @{
    AllNodes = @(        
                @{     
                    NodeName                    = "localhost"
                    ComputerName                = "e01"
                    PSDscAllowPlainTextPassword = $true
                    PSDscAllowDomainUser        = $true
                    Role                        = "DomainMember" 
                    DomainName                  = "cfg.filemilk.net"
                    InterfaceAlias              = "Ethernet"                 
                    AddressFamily               = "Ipv4"
                    DnsServerAddress            = @(
                                                     "192.168.1.2"
                                                  )
                } 
            )  
    } 

# Script block
Configuration Roles 
{ 
    param 
    (
        [Parameter(Mandatory)] 
        [pscredential]$Credential
    ) 
 
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xNetworking
 
    Node $AllNodes.Where{$_.Role -eq "DomainMember"}.Nodename
    {

        LocalConfigurationManager            
        {            
            ActionAfterReboot  = "ContinueConfiguration"            
            ConfigurationMode  = "ApplyOnly"           
            RebootNodeIfNeeded = $true            
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = $Node.DnsServerAddress 
            InterfaceAlias = $Node.InterfaceAlias 
            AddressFamily  = $Node.AddressFamily 
        } 

        xComputer JoinDomain 
        {
            Name          = $Node.ComputerName
            DomainName    = $Node.DomainName
            Credential    = $Credential
            DependsOn     = "[xDnsServerAddress]DnsServerAddress" 
        } 
    } 
}

# Create MOF job
Roles -OutputPath $env:TEMP -ConfigurationData $ConfigurationData -Credential (Get-Credential -UserName cfg\administrator -Message "Domain Admin/Join Credential")

# Configure the DSCLocalConfigurationManager
Set-DSCLocalConfigurationManager -Path $env:TEMP –Verbose  

# Run the MOF job
Start-DscConfiguration -Path $env:TEMP -Wait -Force -Verbose