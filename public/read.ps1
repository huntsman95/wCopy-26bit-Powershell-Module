$hidresults = [HidLibrary.HidDevices]::Enumerate(0x2518, 0x6018)
[HidLibrary.HidDevice]$HIDDEV = [System.Linq.Enumerable]::FirstOrDefault($hidresults)
$global:synchash = [hashtable]::Synchronized(@{})

Register-EngineEvent -SourceIdentifier 'HIDDEV.DataArrived' -Action {
    $bigint = [System.Numerics.BigInteger]::new($event.sourceargs.data)
    switch ($bigint) {
        -832330253400318 { $synchash['carddata'] = -1 }
        -182112591896049662 { Write-Verbose 'BEEP!' }
        Default {
            # Write-Host (($event.sourceargs.data | ForEach-Object { ($_.ToString('X2')).PadLeft(2, '0') }) -join ' ')
            # $global:CARDDATA = $event.sourceargs.data
            $synchash['carddata'] = $event.sourceargs.data
        }
    }
} | Out-Null

$synchash['HIDDEV'] = $HIDDEV
$synchash['host'] = $host
$synchash['data'] = $null
if (-not $hidreadjob) {
    $global:hidreadjob = Start-ThreadJob -ScriptBlock {
        $byteList = [System.Collections.Generic.List[byte]]::new()
        while ($true) {
            Start-Sleep -Milliseconds 100
            $byteList.Clear()
            $data = $args[0].HIDDEV.ReadReport(0x02) | Select-Object -ExpandProperty Data
            if ($data -eq $null) { continue }
            for ($i = 0; $i -lt $data.count; $i++) {
                [void]$byteList.Add($data[$i])
                if ($data[$i] -eq 0xFD) {
                    break
                }
            }
            $args[0]['data'] = $byteList.ToArray()
            $data = [PSCustomObject]@{
                data = $byteList.ToArray()
            }
            $args[0].host.runspace.events.generateevent('HIDDEV.DataArrived', $null, @($data), $null)
        }
    } -ArgumentList $synchash
}

Function Convert-HexToByte {
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory = $true)] [String]$Value
    )
    $bytes = New-Object -TypeName byte[] -ArgumentList ($Value.Length / 2)
    for ($i = 0; $i -lt $Value.Length; $i += 2) {
        $bytes[$i / 2] = [Convert]::ToByte($Value.Substring($i, 2), 16)
    }
    return [byte[]]$bytes
}

function Write-HID {
    param(
        [byte[]]$Data
    )
    
    $result = [PSCustomObject]@{
        Success = ($HIDDEV.Write($Data))
    }

    return $result
}

function Read-26BitCard {
    $synchash['carddata'] = $null
    $SCAN_CMDS = @(
        '02010ce602ff006a01000898fe' #READ RFID COMMAND
        '02010fe802ff00405004050101016afe' #BEEP READER
    )
    foreach ($SCAN_CMD in $SCAN_CMDS) {
        $ddd = Convert-HexToByte -Value $SCAN_CMD
        Write-HID -Data $ddd | Out-Null
        Start-Sleep -Milliseconds 50
    }

    $timeout = 250
    while (($timeout -gt 0)) {
        Start-Sleep -Milliseconds 1
        $timeout = $timeout - 1
        if ($synchash['carddata']) { break }
    }
    if($synchash['carddata'] -eq -1) {
        throw 'Read Failure'
    }
    if($timeout -le 0) {
        throw 'Read Timed Out'
    }
    Get-CardDataFromHID -CARDDATA $synchash['carddata']
    $synchash['carddata'] = $null
}