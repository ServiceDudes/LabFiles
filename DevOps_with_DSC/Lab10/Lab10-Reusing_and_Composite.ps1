# Lab xyz - Set up Desired State Configuration to encrypt MOF credentials

# --------------------------------------------------------------------------------

# Lab10.1 - Configure web site for client certificate distribution

# Run on c01 (LAB-DSC-002)

Install-Module cChoco             -RequiredVersion 2.0.5.22
Install-Module xWebAdministration -RequiredVersion 1.10.0.0

$ConfigurationData = @{

    AllNodes = @(
        @{
            NodeName                     = "*"
            DomainName                   = "cfg.filemilk.net"
            InterfaceAlias               = "Ethernet"                 
            AddressFamily                = "Ipv4"
            DnsServerAddress             = @("192.168.1.2")
        }        
        @{
            NodeName                     = "e01"
            Role                         = "MailServer"
            IPAddress                    = "192.168.1.4"
            Applications                 = @(
                @{
                    Ensure               = "Present"
                    Name                 = "7zip"
                }
            )
            Packages                     = @(
                @{
                    Ensure               = "Present"
                    Name                 = "hMailServer 5.6.4-B2283"
                    Path                 = "$env:TEMP\hMailServer-5.6.4-B2283.exe"
                    ProductId            = ""
                    Arguments            = "/VERYSILENT"
                    URI                  = "https://www.hmailserver.com/download_file?downloadid=249"
                }
            )
        }
        @{
            NodeName                     = "s01"
            Role                         = "MemberServer"
            IPAddress                    = "192.168.1.5"
            Features                     = @(
                @{
                    Ensure               = "Present"
                    Name                 = "Web-Mgmt-Console"
                }
            )
        }
    );

    RoleDefinitions = 
    @{
        MemberServer                     = @(
                @{
                    Applications         = @(
                        @{
                            Ensure       = "Present"
                            Name         = "bginfo"
                        }
                    )
                }
            )
        WebServer                        = @(
                @{
                    Features             = @(
                        @{
                            Ensure       = "Present"
                            Name         = "Web-Server"
                        }
                        @{
                            Ensure       = "Present"
                            Name         = "Web-Asp-Net45"
                        }
                    )
                    Configuration        = @(
                        @{
                            Ensure       = "Present"
                            Name         = "Default Web Site"
                            PhysicalPath = "C:\inetpub\wwwroot"
                        }
                    )
                }
            )
        DatabaseServer                   = @(
                @{
                    Application          = @(
                        @{
                            Ensure       = "Present"
                            Name         = "mssqlserver2014express"
                        }
                    )
                }
            )
     } 
}

Configuration ChocoApplication
{
    param 
    (
        [Parameter(Mandatory)] 
        $Applications
    )

    Import-DscResource -ModuleName cChoco

    cChocoInstaller installChoco
    {
        InstallDir = "c:\choco"
    }

    ForEach ($Application in $Applications)   
    {

        [string]$Name = ""

        $Application.GetEnumerator() | % {
            If ($_.key -eq "Name")   { $Name = $_.value }
        }

        cChocoPackageInstaller $Name.Replace(' ','')
        {
            Name      = $Name
            DependsOn = "[cChocoInstaller]installChoco"
        }

    }

}

Configuration PackageApplication
{
    param 
    (
        [Parameter(Mandatory)] 
        $Applications
    )

    ForEach ($Application in $Applications)   
    {

        [string]$Ensure    = ""
        [string]$Name      = ""
        [string]$Path      = ""
        [string]$ProductId = ""
        [string]$Arguments = ""
        [string]$URI       = ""

        $Application.GetEnumerator() | % {
            If ($_.key -eq "Ensure")    { $Ensure    = $_.value }
            If ($_.key -eq "Name")      { $Name      = $_.value }
            If ($_.key -eq "Path")      { $Path      = $_.value }
            If ($_.key -eq "ProductId") { $ProductId = $_.value }
            If ($_.key -eq "Arguments") { $Arguments = $_.value }
            If ($_.key -eq "URI")       { $URI       = $_.value }
        }

        If (-not(Test-Path -Path $Path -ErrorAction Ignore))
        {
            $WebClient = New-Object System.Net.WebClient
            $WebClient.DownloadFile($URI, $Path)
        }

        Package $Name        {            Ensure     = $Ensure            Name       = $Name            Path       = $Path            ProductId  = $ProductId            Arguments  = $Arguments            ReturnCode = 0        }

    }

}

Configuration WebServer
{
    param 
    (
        [Parameter(Mandatory)] 
        [string]$Ensure,

        [Parameter(Mandatory)] 
        [string]$Name,

        [Parameter(Mandatory)] 
        [string]$PhysicalPath,

        [Parameter(Mandatory)] 
        $Features
    )

    Import-DscResource -ModuleName xWebAdministration

    ForEach ($Feature in $Features)   
    {

        [string]$FeatureEnsure = ""
        [string]$FeatureName   = ""

        $Feature.GetEnumerator() | % {
            If ($_.key -eq "Ensure") { $FeatureEnsure = $_.value }
            If ($_.key -eq "Name")   { $FeatureName   = $_.value }
        }

        WindowsFeature $FeatureName.Replace(' ','')
        {
            Ensure = $FeatureEnsure
            Name   = $FeatureName
        }

    }

    File $Name.Replace(' ','')
    {
        Ensure          = $Ensure
        Type            = "Directory"
        DestinationPath = $PhysicalPath
    }

    xWebsite $Name.Replace(' ','')
    {
        Ensure          = $Ensure
        Name            = $Name
        State           = "Started"
        PhysicalPath    = $PhysicalPath
    }

}

Configuration BuildServer
{

    Param(
        [Parameter(Mandatory=$True)]
        [String[]]$ConfigurationName
    )

    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node $ConfigurationName
    {

        If ($ConfigurationName.ToLower() -eq "memberserver")
        {
            $Applications = @($ConfigurationData.RoleDefinitions.MemberServer.Applications)

            ChocoApplication "MemberServer"
            {
                Applications = $Applications
            }

        }

        If ($ConfigurationName.ToLower() -eq "webserver")
        {

            $Features = @($ConfigurationData.RoleDefinitions.WebServer.Features)

            WebServer $ConfigurationData.RoleDefinitions.WebServer.Configuration.Name.Replace(' ','')
            {
                Ensure       = $ConfigurationData.RoleDefinitions.WebServer.Configuration.Ensure
                Name         = $ConfigurationData.RoleDefinitions.WebServer.Configuration.Name
                PhysicalPath = $ConfigurationData.RoleDefinitions.WebServer.Configuration.PhysicalPath
                Features     = $Features
            }

        }

        If ($ConfigurationName.ToLower() -eq "databaseserver")
        {

            $Applications = @($ConfigurationData.RoleDefinitions.DatabaseServer.Application)

            ChocoApplication "DatabaseServer"
            {
                Applications = $Applications
            }

        }

    }

    Node $AllNodes.Where{$_.NodeName -eq $ConfigurationName}.Nodename
    {

        If ($Node.Applications)
        {

            $Applications = @($Node.Applications)

            ChocoApplication "$env:COMPUTERNAME"
            {
                Applications = $Applications
            }

        }

        If ($Node.Features)
        {
            foreach ($Feature in $Node.Features)
            {

                [string]$Ensure = ""
                [string]$Name   = ""

                $Feature.GetEnumerator() | % {
                    If ($_.key -eq "Ensure") { $Ensure = $_.value }
                    If ($_.key -eq "Name")   { $Name   = $_.value }
                }

                WindowsFeature $Name.Replace(' ','')
                {
                    Ensure = $Ensure
                    Name   = $Name
                }

            }
        }

        If ($Node.Packages)
        {

            $Package = @($Node.Packages)

            PackageApplication "$env:COMPUTERNAME"
            {
                Applications = $Package
            }

        }

    }

}

# Define computers to create MOF jobs for
$ConfigurationNames = @("MemberServer","WebServer","DatabaseServer","e01","s01")

# Create client unique GUID:s, Generate MO:s and create a CSV file with server names and GUID:s for reference
ForEach ($ConfigurationName in $ConfigurationNames)
{
    BuildServer -ConfigurationName $ConfigurationName -OutputPath $PullShare -ConfigurationData $ConfigurationData
    ise "$PullShare\$ConfigurationName.mof"
}

# Create checksum for MOF jobs
New-DSCCheckSum -ConfigurationPath "C:\PullShare" -OutPath $PullShare -Verbose -Force