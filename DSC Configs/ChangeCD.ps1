configuration ChangeCD
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

    }
}