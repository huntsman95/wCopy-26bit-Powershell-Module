$hidresults = [HidLibrary.HidDevices]::Enumerate(0x2518, 0x6018)
[HidLibrary.HidDevice]$HIDDEV = [System.Linq.Enumerable]::FirstOrDefault($hidresults)

function Write-HID {
    param(
        [byte[]]$Data
    )
    
    $result = [PSCustomObject]@{
        Success = ($HIDDEV.Write($Data))
    }

    return $result
}

function Write-26BitCard {
    param(
        [Parameter(Mandatory = $true)] [Int]$FacilityCode
        ,
        [Parameter(Mandatory = $true)] [Int]$CardNumber
    )
    $BlockData = Get-T55x7BlockData -FC $FacilityCode -CC $CardNumber
    $WRITE_CMDS = @(
        '0201' + '16' + '1c0a' + 'ff0066001e48e801001200' + '01' + $BlockData[1] #BLOCK 1
        '0201' + '16' + '200a' + 'ff0066001e48e801001200' + '02' + $BlockData[2] #BLOCK 2
        '0201' + '16' + '240a' + 'ff0066001e48e801001200' + '03' + $BlockData[3] #BLOCK 3
        '0201' + '16' + '280a' + 'ff0066001e48e801001200' + '00' + $BlockData[0] #CONFIG BLOCK 0
        '0201' + '0f' + '300a' + 'ff0040500405010101' #BEEP READER
    )
    foreach ($WRITE_CMD in $WRITE_CMDS) {
        $WRITE_CMD_CHECKSUM = Get-PacketCheckSum $WRITE_CMD
        $WRITE_CMD = $WRITE_CMD + $WRITE_CMD_CHECKSUM + 'fe'
        $BINDATA = Convert-HexToByte -Value $WRITE_CMD
        Write-Host ("Writing Packet: " + ($WRITE_CMD).ToUpper())
        Write-HID -Data $BINDATA | Out-Null
        Start-Sleep -Milliseconds 50
    }
    Write-Host 'Done writing!'
}