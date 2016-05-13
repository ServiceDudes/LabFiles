enum Ensure
{
    Absent
    Present
}


[DscResource()]
class chMailAccounting
{

    [DscProperty(Mandatory)]
    [Ensure]$Ensure

    [DscProperty(Key)]
    [string]$DomainName

    [DscProperty(Key)]
    [string]$AccountAddress

    [DscProperty(Mandatory)]
    [string]$AccountADUserName

    [DscProperty(Mandatory)]
    [string]$AccountADDomain

    [DscProperty(Mandatory)]
    [string]$AdminUsername
    
    [DscProperty(Mandatory)]
    [string]$AdminPassword   

    [void]Set()
    {
        $hmail = Connect-hMailServer -Username $this.AdminUsername -Password $this.AdminPassword
        $domain = $false
        $user = $false
        try
        {            
            $domain = $hmail.Domains.ItemByName($this.DomainName)            
        }
        catch 
        {
        }
        try
        {            
            $user = $domain.Accounts.ItemByAddress($this.AccountAddress)
        }
        catch 
        {
        }
        
        if ($this.Ensure)
        {
            if (-not $domain)
            {
                $domain = $hMail.Domains.Add()
                $domain.Name = $this.DomainName
                $domain.Active = $true
                $domain.Save()
            }
            if (-not $user)
            {
                $account = $domain.Accounts.Add()
                $account.Address = $this.AccountAddress
                $account.ADUsername = $this.AccountADUserName
                $account.ADDomain = $this.AccountADDomain
                $account.Active = $true
                $account.Save()
            }
        }
        else 
        {
            if ($domain)
            {
                $domain.Delete()
            }
        }


    }

    [bool]Test()
    {
        $hmail = Connect-hMailServer -Username $this.AdminUsername -Password $this.AdminPassword
        try
        {            
            $domain = $hmail.Domains.ItemByName($this.DomainName)
            $result = $true
        }
        catch [System.Runtime.InteropServices.COMException]
        {
            <#
            #extra lab
            #if ("0x{0:x}".ToUpper() -f $_.Exception.ErrorCode -eq '0x8002000B')
            #{
            #    $present = $false
            #}
            #>
            $result = $false
            return $this.Ensure -eq $result
        }
        try
        {            
            $user = $domain.Accounts.ItemByAddress($this.AccountAddress)
            $result = $true
        }
        catch [System.Runtime.InteropServices.COMException]
        {
            <#
            #extra lab
            #if ("0x{0:x}".ToUpper() -f $_.Exception.ErrorCode -eq '0x8002000B')
            #{
            #    $present = $false
            #}
            #>
            $result = $false
            return $this.Ensure -eq $result   
        }        
        return $this.Ensure -eq $result
        #Extra lab:
        #Also verify that the accountADDomain and accountausername is correct
    }

    [chMailAccounting]Get()
    {
        return $this
    }
}
function Connect-hMailServer ($Username, $Password)
{
    #connect to the API
    $hMail = New-Object -ComObject 'hMailServer.Application'
    #Need to authenticate before working with it
    #and we dont want it to return anything
    $null = $hMail.Authenticate($username,$password)
    return $hMail
}