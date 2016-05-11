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