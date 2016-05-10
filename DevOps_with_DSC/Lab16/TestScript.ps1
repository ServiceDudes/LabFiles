#Install-Module cChoco             -RequiredVersion 2.0.5.22
#Install-Module xWebAdministration -RequiredVersion 1.10.0.0
Import-DscResource -ModuleName cChoco
Import-DscResource -ModuleName xWebAdministration
Import-DscResource –ModuleName PSDesiredStateConfiguration