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
