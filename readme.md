# wCopy RFID Reader Writer PS Module

## Summary
Powershell 7 module to read/write 26-bit Wiegand RFID cards using the NSCCN wCopy RFID Reader/Writer. (Cheap Chinese RFID reader/writer purchased on eBay or Aliexpress). This should allow you to use the device for the purpose of cloning standard 26-bit Wiegand cards without running sketchy closed-source Chinese software.

**PLEASE NOTE** This module only runs on Powershell 7.0 and higher due to the use of thread-jobs for multi-threading (reading HID reports). You can replace this with a runspace if you would like to use this on Powershell 5.1.

Device Info:
- VID: 0x2518
- PID: 0x6018
- Model: wCopy NSR109-HIDIC V806N

## Dependencies

- [HidLibrary](https://www.nuget.org/packages/HidLibrary/) >= 3.3.40

## Usage

```powershell
Import-Module .\wCopy26bit.psd1

Read-26BitCard

FC   CC
--   --
30 1234

Write-26BitCard -FacilityCode 44 -CardNumber 6969
Writing Packet: 0201161C0AFF0066001E48E801001200011D555955DBFE
Writing Packet: 020116200AFF0066001E48E801001200025565669541FE
Writing Packet: 020116240AFF0066001E48E801001200035A696A596BFE
Writing Packet: 020116280AFF0066001E48E801001200000010706010FE
Writing Packet: 02010F300AFF00405004050101011AFE
Done writing!

```