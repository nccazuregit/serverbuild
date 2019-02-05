configuration Default2016
{
    node "localhost"
    {
        Script ChangeCDROM
            {
            SetScript = {
                $cdromDrive = Get-CimInstance -Class Win32_CDROMDrive | Select-Object -First 1 
                if ($cdromDrive)
                    {
                    Get-CimInstance -Class Win32_Volume -Filter "DriveLetter = '$($cdromDrive.Drive)'" |
                        Set-CimInstance -Arguments @{
                            DriveLetter='Z:'
                        } | Out-Null
                    }
            }

            TestScript = {
                $expectedDriveLetter = 'Z'
                
                $cdromDrive = Get-CimInstance -Class Win32_CDROMDrive | Select-Object -First 1 
                if ($cdromDrive)
                    {
                        $driveLetter = ($cdromDrive.Drive -replace ':','')
                        $result = $driveLetter -eq $expectedDriveLetter
                    }
                else
                    { 
                        $result = $false
                    }

                return $result
            }

            GetScript = {
                $driveLetter = ''
                $cdromDrive = Get-CimInstance -Class Win32_CDROMDrive | Select-Object -First 1 
                if ($cdromDrive)
                {
                    $driveLetter = $cdromDrive.Drive
                }

                return @{
                    DriveLetter = ($driveLetter -replace ':','')
                }
            }
        }


        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name = "RSAT"
        }

        Registry Fix1
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\QualityCompat"
            ValueName = "cadca5fe-87d3-4b96-b7fb-a231484277cc"
            ValueData = "0"
            ValueType = "Dword"
        }

        Registry Fix2
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            ValueName = "FeatureSettingsOverride"
            ValueData = "0"
            ValueType = "Dword"
        }
    
        Registry Fix3
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            ValueName = "FeatureSettingsOverrideMask"
            ValueData = "3"
            ValueType = "Dword"
        }
    
        Registry Fix4
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
            ValueName = "MinVmVersionForCpuBasedMitigations"
            ValueData = "1"
            ValueType = "String"
        }

    }
}

