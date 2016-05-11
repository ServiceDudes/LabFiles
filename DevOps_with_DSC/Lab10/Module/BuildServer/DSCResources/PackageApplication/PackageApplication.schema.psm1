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
