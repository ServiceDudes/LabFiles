Configuration CreateDomain
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xDisk
    Import-DscResource -ModuleName cDisk
    
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter | Where-Object Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        Script AddADDSFeature {
            SetScript  = {
                Add-WindowsFeature "AD-Domain-Services" -ErrorAction SilentlyContinue   
            }
            GetScript      =  { @{} }
            TestScript     =  { $false }
        }
	
	    WindowsFeature DNS 
        { 
            Ensure            = "Present" 
            Name              = "DNS"		
        }

        Script script1
	    {
      	    SetScript         =  { 
		        Set-DnsServerDiagnostics -All $true
                Write-Verbose -Verbose "Enabling DNS client diagnostics" 
            }
            GetScript         =  { @{} }
            TestScript        = { $false }
	        DependsOn         = "[WindowsFeature]DNS"
        }

	    WindowsFeature DnsTools
	    {
	        Ensure            = "Present"
            Name              = "RSAT-DNS-Server"
	    }

        xDnsServerAddress DnsServerAddress 
        { 
            Address           = '127.0.0.1' 
            InterfaceAlias    = $InterfaceAlias
            AddressFamily     = 'IPv4'
	        DependsOn         = "[WindowsFeature]DNS"
        }

        xWaitforDisk Disk2
        {
             DiskNumber       = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount       = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber        = 2
            DriveLetter       = "F"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure    = "Present" 
            Name      = "AD-Domain-Services"
	        DependsOn ="[cDiskNoRestart]ADDataDisk", "[Script]AddADDSFeature"
        } 
         
        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath                  = "F:\NTDS"
            LogPath                       = "F:\NTDS"
            SysvolPath                    = "F:\SYSVOL"
	        DependsOn                     = "[WindowsFeature]ADDSInstall"
        } 

        LocalConfigurationManager 
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
   }
}


Configuration CreatePKI
{}


Configuration JoinDomain
{ 
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement

    $domainCreds = New-Object System.Management.Automation.PSCredential ("$domainName\$($adminCreds.UserName)", $adminCreds.Password)
   
    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADPowershell
        {
            Name       = "RSAT-AD-PowerShell"
            Ensure     = "Present"
        } 

        xComputer DomainJoin
        {
            Name       = $env:COMPUTERNAME
            DomainName = $domainName
            Credential = $domainCreds
            DependsOn  = "[WindowsFeature]ADPowershell" 
        }
   }
}


Configuration PullServer
{}


Configuration Gateway
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 


    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName = $domainName 
            adminCreds = $adminCreds 
        }

        WindowsFeature RDS-Gateway
        {
            Ensure     = "Present"
            Name       = "RDS-Gateway"
        }

        WindowsFeature RDS-Web-Access
        {
            Ensure     = "Present"
            Name       = "RDS-Web-Access"
        }
    }
}


Configuration SessionHost
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds
    ) 


    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName = $domainName 
            adminCreds = $adminCreds 
        }

        WindowsFeature RDS-RD-Server
        {
            Ensure     = "Present"
            Name       = "RDS-RD-Server"
        }
    }
}


Configuration RDSDeployment
{
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$domainName,

        [Parameter(Mandatory)]
        [PSCredential]$adminCreds,

        # Connection Broker Node name
        [String]$connectionBroker,
        
        # Web Access Node name
        [String]$webAccessServer,

        # Gateway external FQDN
        [String]$externalFqdn,
        
        # RD Session Host count and naming prefix
        [Int]$numberOfRdshInstances      = 1,
        [String]$sessionHostNamingPrefix = "SessionHost-",

        # Collection Name
        [String]$collectionName,

        # Connection Description
        [String]$collectionDescription

    ) 

    # Dependencies:
    Import-DscResource -ModuleName PSDesiredStateConfiguration -ModuleVersion 1.1
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xRemoteDesktopSessionHost
   
    # Variables:
    $localhost   = [System.Net.Dns]::GetHostByName((hostname)).HostName
    $username    = $adminCreds.UserName -split '\\' | select -last 1
    $domainCreds = New-Object System.Management.Automation.PSCredential ("$domainName\$username", $adminCreds.Password)

    # Validations:
    if (-not $connectionBroker)   { $connectionBroker = $localhost }
    if (-not $webAccessServer)    { $webAccessServer  = $localhost }

    if ($sessionHostNamingPrefix)
    { 
        $sessionHosts = @( 0..($numberOfRdshInstances-1) | % { "$sessionHostNamingPrefix$_.$domainname"} )
    }
    else
    {
        $sessionHosts = @( $localhost )
    }

    if (-not $collectionName)         { $collectionName = "Desktop Collection" }
    if (-not $collectionDescription)  { $collectionDescription = "A sample RD Session collection up in cloud." }


    # Configuration:
    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded    = $true
            ConfigurationMode     = "ApplyOnly"
        }

        DomainJoin DomainJoin
        {
            domainName            = $domainName 
            adminCreds            = $adminCreds 
        }

        WindowsFeature RSAT-RDS-Tools
        {
            Ensure                = "Present"
            Name                  = "RSAT-RDS-Tools"
            IncludeAllSubFeature  = $true
        }

        WindowsFeature RDS-Licensing
        {
            Ensure                = "Present"
            Name                  = "RDS-Licensing"
        }

        xRDSessionDeployment Deployment
        {
            ConnectionBroker      = $connectionBroker
            WebAccessServer       = $webAccessServer
            SessionHosts          = $sessionHosts
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[DomainJoin]DomainJoin"
        }


        xRDServer AddLicenseServer
        {           
            Role                  = 'RDS-Licensing'
            Server                = $connectionBroker
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[xRDSessionDeployment]Deployment"
        }

        xRDLicenseConfiguration LicenseConfiguration
        {
            ConnectionBroker      = $connectionBroker
            LicenseServers        = @( $connectionBroker )
            LicenseMode           = 'PerUser'
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[xRDServer]AddLicenseServer"
        }


        xRDServer AddGatewayServer
        {     
            Role                  = 'RDS-Gateway'
            Server                = $webAccessServer
            GatewayExternalFqdn   = $externalFqdn
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[xRDLicenseConfiguration]LicenseConfiguration"      
        }

        xRDGatewayConfiguration GatewayConfiguration
        {
            ConnectionBroker      = $connectionBroker
            GatewayServer         = $webAccessServer
            ExternalFqdn          = $externalFqdn
            GatewayMode           = 'Custom'
            LogonMethod           = 'AllowUserToSelectDuringConnection'
            UseCachedCredentials  = $true
            BypassLocal           = $false
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[xRDServer]AddGatewayServer"
        } 
        

        xRDSessionCollection Collection
        {            
            ConnectionBroker      = $connectionBroker
            CollectionName        = $collectionName
            CollectionDescription = $collectionDescription            
            SessionHosts          = $sessionHosts
            PsDscRunAsCredential  = $domainCreds
            DependsOn             = "[xRDGatewayConfiguration]GatewayConfiguration"
        }

    }
}

Configuration BuildServer
{}