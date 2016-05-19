                #region configure CA settings and prepare AIA / CDP
                New-Item c:\CDP -ItemType directory -Force
                Copy-Item C:\Windows\System32\CertSrv\CertEnroll\*.crt C:\CDP\$($using:Node.CAName).crt -Force
                Get-CAAuthorityInformationAccess | Remove-CAAuthorityInformationAccess -Force
                Get-CACrlDistributionPoint | Remove-CACrlDistributionPoint -Force
                Add-CAAuthorityInformationAccess -Uri http://$($using:Node.CDPURL)/$($using:Node.CAName).crt -AddToCertificateAia -Force
                Add-CACrlDistributionPoint -Uri C:\CDP\<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl -PublishToServer -PublishDeltaToServer -Force
                Add-CACrlDistributionPoint -Uri http://$($using:Node.CDPURL)/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl -AddToCertificateCdp -AddToFreshestCrl -Force
                #endregion configure CA settings and prepare AIA / CDP

                #region create CDP / AIA web site
                Import-Module 'C:\Windows\system32\WindowsPowerShell\v1.0\Modules\WebAdministration\WebAdministration.psd1'
                New-Website -Name CDP -HostHeader $($using:Node.CDPURL) -Port 80 -IPAddress * -Force
                Set-ItemProperty 'IIS:\Sites\CDP' -Name physicalpath -Value C:\CDP
                Set-WebConfigurationProperty -PSPath 'IIS:\Sites\CDP' -Filter /system.webServer/directoryBrowse  -Name enabled -Value true
                Set-WebConfigurationProperty -PSPath 'IIS:\Sites\CDP' -Filter /system.webServer/security/requestfiltering  -Name allowDoubleEscaping -Value true
                attrib +h C:\CDP\web.config
                #endregion create CDP / AIA web site
 
                #region restart CA service and publish CRL
                Restart-Service -Name CertSvc
                do
                {
                    Start-Sleep -Seconds 2
                }
                while ((Get-Service certsvc).Status -ne 'Running')
                certutil -CRL
                #endregion restart CA service and publish CRL
 
                #region add webserver template
                
                $DN = (Get-ADDomain).DistinguishedName
                $WebTemplate = "CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$DN"
                DSACLS $WebTemplate /G "Authenticated Users:CA;Enroll"
 
                certutil -setcatemplates +WebServer
                #endregion add webserver template