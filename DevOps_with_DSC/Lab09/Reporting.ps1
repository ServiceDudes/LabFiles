$PullServer = 'config.filemilk.net'

function Format-HumanJson
{
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [object[]]$Reports,
        $JSPath = 'C:\Web\js\demo.js',
        $htmlPath = 'C:\Web\details.html'
    )

    $js = Get-Content -Raw $JSPath

    [string]$json = "["
    foreach ($report in $reports)
    {
        $json += $report + ","
    }
    $json = $json.TrimEnd(",")
    $json += "]"

    $js = $js -replace "(?<=var jsonString = ')(.*)(?=';)",$json.Replace("\`"","")
    Set-Content -Path $JSPath -Value $js -Force

    & $htmlPath
}

function Get-ComputerDSCReports
{    
    param($ComputerName = $env:COMPUTERNAME, $serviceURL = "https://$($PullServer)/PSDSCPullServer.svc", [switch]$Raw )

    $configurationId = (Get-DscLocalConfigurationManager -CimSession (New-CimSession -ComputerName $ComputerName)).AgentId
    $requestUri = "$serviceURL/Node(ConfigurationId='$configurationId')/StatusReports"
    $contentType = "application/json;odata=minimalmetadata;streaming=true;charset=utf-8"
    $headers = @{Accept = "application/json";ProtocolVersion = "2.0"}

    $requestParams =@{
        Uri = $requestUri
        ContentType = $contentType
        UseBasicParsing = $true
        Headers = $headers
    }

    $request = Invoke-WebRequest @requestParams
   
    $object = ConvertFrom-Json $request.content
    if ($raw)
    {
        return $request.Content
    }
    return $object.value
}

$reports = Get-ComputerDSCReports

#Get reports by time
$reports | Select-Object StartTime,OperationType,JobId | Sort-Object StartTime -Descending

#get specific report
$reports | Where-Object JobId -eq 'e22ba9cf-0c56-11e6-80c8-00155d007c31' | Select-Object -ExpandProperty StatusData | ConvertFrom-Json

#Get Failed status
$reports | Where-Object StatusData -Like "*Failure*" | Select-Object -ExpandProperty StatusData | ConvertFrom-Json

#present data using json formatting for humans requires the reporting folder to be placed
$reportStatusData = Get-ComputerDSCReports | Sort-Object StartTime -Descending | select -First 10 -ExpandProperty StatusData
Format-HumanJson -Reports $reportStatusData