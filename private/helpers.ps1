

function ConvertTo-Manchester {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $InputBinaryString
    )
    process {
        ($InputBinaryString.ToCharArray() | ForEach-Object { 
            switch ($_) {
                '1' { '10' }
                '0' { '01' }
            }
        }) -join ''
    }
}

function ConvertTo-HexString {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $InputBinaryString
    )
    process {
        [Convert]::ToInt64($InputBinaryString, 2).ToString('X')
    }
}

function ConvertTo-BinaryString {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [int]
        $InputNumber
        ,
        [Parameter(Mandatory = $false)]
        [int]
        $Pad = 0
    )
    process {
        [convert]::ToString($InputNumber, 2).PadLeft($Pad, '0')
    }
}

function Get-WiegandData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $FC
        ,
        [Parameter(Mandatory = $true)]
        [int]
        $CC
    )
    process {

        $BINDATA = [string]((ConvertTo-BinaryString -InputNumber $FC -Pad 8) + (ConvertTo-BinaryString -InputNumber $CC -Pad 16))
        $EPc = 0
        $OPc = 1
        foreach ($bit in $BINDATA.Substring(0, 12).ToCharArray()) {
            if ($bit -eq '1') {
                $EPc++
            }
        }
        foreach ($bit in $BINDATA.Substring(12, 12).ToCharArray()) {
            if ($bit -eq '1') {
                $OPc++
            }
        }
        $outObj = [PSCustomObject]@{
            EP   = $EPc % 2
            DATA = $BINDATA
            OP   = $EPc % 2
        }

        $outObj | Add-Member -MemberType ScriptMethod -Name ToString -Value { '{0}{1}{2}' -f $this.EP, $this.DATA, $this.OP } -Force
        return $outObj
    }
}

function Get-T55x7BlockData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $FC
        ,
        [Parameter(Mandatory = $true)]
        [int]
        $CC
    )
    process {
        $ConfigBlock0 = 0x00107060 | ConvertTo-BinaryString -Pad 32
        $Preamble = '00011101'
        $Data = '000000100000000001' + ((Get-WiegandData -FC $FC -CC $CC).ToString())
        $ManchesterData = ConvertTo-Manchester -InputBinaryString $Data
        $ManchesterData = $configBlock0 + $Preamble + $ManchesterData
        $hashtable = @{}
        for ($i = 0; $i -lt 4; $i++) {
            $hashtable[$i] = (($ManchesterData.Substring($i * 32, 32)) | ConvertTo-HexString).PadLeft(8, '0')
        }

        return $hashtable
    }
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

function Get-PacketCheckSum {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Packet
    )
    process {
        if ($Packet -notlike '*00fe') {
            $Packet = $Packet + '00fe'
        }
        [int]$sum = 0
        $PacketArray = $Packet -split '(..)' -ne '' | ForEach-Object { Convert-HexToByte -Value $_ }
        foreach ($byte in $PacketArray) {
            $sum += $byte
        }
        return (255 - ($sum % 256)).ToString('X').PadLeft(2, '0')
    }
}

function New-HIDPacket {
    [CmdletBinding()]
    param (
        $Endpoint, # 0x02
        $Prefix, #0x0116
        $Counter, # 0x0001
        $Command # 0xff0040500405010101
    )
    process {
        
    }
}

function Get-CardDataFromHID {
    param([Parameter(Mandatory = $true)]$CARDDATA)
    function BitsToInt {
        param([Parameter(ValueFromPipeline = $true)][int]$BIT)
        begin {
            $buffer = 0
        }
        process {
            $buffer = $buffer -shl 1
            $buffer = $buffer -bor $BIT
        }
        end {
            $buffer
        }
    }

    $BITARRAY = ((($CARDDATA | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') }) -join '') -split '(.)' -ne '') | ForEach-Object { [int]::Parse($_) }

    [PSCustomObject]@{
        #EP = $BITARRAY[70]
        FC = $BITARRAY[71..78] | BitsToInt
        CC = $BITARRAY[79..94] | BitsToInt
        #OP = $BITARRAY[95]
    }
}