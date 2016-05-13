#Username: root
#Password: P@ssw0rd
$Credentials = Get-Credential
$CimOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -UseSsl -SkipRevocationCheck
$CimSession = New-CimSession -Credential $Credentials -ComputerName 192.168.1.10 -port 5986 -Authentication Basic -SessionOption $CimOptions
Get-CimInstance -CimSession $CimSession -namespace root/omi -ClassName omi_identify

#Configure apache
Configuration PenguinConfiguration{

    Import-DscResource -Module nx
    Import-DscResource -Module nxNetworking

    Node  '192.168.1.10'{
        nxFile ExampleFile {

            DestinationPath = '/tmp/example'
            Contents = 'hello world `n'
            Ensure = 'Present'
            Type = 'File'
        }
        nxPackage httpd {
            Ensure = 'Present'
            PackageManager = 'Yum'
            Name = 'httpd'
        }
        nxFirewall http {
            Name = 'http in'
            InterfaceName = 'eth0' 
            FirewallType = 'firewalld'
            Ensure = 'Present'
            Access = 'Allow'
            Direction = 'INPUT'
            DestinationPort = '80'
            Protocol = 'tcp'
            Position = 'before-end'
        }
        nxFirewall https {
            Name = 'https in'
            InterfaceName = 'eth0' 
            FirewallType = 'firewalld'
            Ensure = 'Present'
            Access = 'Allow'
            Direction = 'INPUT'
            DestinationPort = '443'
            Protocol = 'tcp'
            Position = 'before-end'
        }
        nxService Apache {
            DependsOn = '[nxPackage]httpd'
            Name = 'httpd'
            Enabled = $true
            Controller = 'systemd'
            State = 'Running'
        }
        nxFile IndexHtml {
            SourcePath = 'https://raw.githubusercontent.com/ServiceDudes/LabFiles/master/DevOps_with_DSC/Lab13/Index.html'
            DestinationPath = '/var/www/html/index.html'
            Ensure = 'Present'
            Type = 'File'
            DependsOn = '[nxService]Apache'
        }
        nxFile LayoutCss {
            SourcePath = 'https://raw.githubusercontent.com/ServiceDudes/LabFiles/master/DevOps_with_DSC/Lab13/layout.css'
            DestinationPath = '/var/www/html/layout.css'
            Ensure = 'Present'
            Type = 'File'
            DependsOn = '[nxFile]IndexHtml'
        }
    }
    
}

PenguinConfiguration -OutputPath:'C:\temp'
Start-DscConfiguration -Path 'c:\temp' -CimSession $CimSession -Wait -Verbose
Get-DscConfiguration -CimSession $CimSession

Start-Process  "http://192.168.1.10"