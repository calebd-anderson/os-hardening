# Windows Scripts
## `ip_locate.ps1`
IP address analysis leveraging the [ipinfo.io](https://ipinfo.io/) API to display a report about an ip address.
## `dpapi_password.ps`
Save an alias for lesspass:
```powershell
# create the profile if it doesn't exist
New-Item -ItemType File -Path $PROFILE -Force
# open the profile in notepad
notepad $PROFILE
# add the following
# remove lp is normally an alias for Out-Printer
Remove-Item Alias:lp -Force -ErrorAction SilentlyContinue

function lp {
    & (Join-Path $env:USERPROFILE '<path-to>\dpapi_password.ps1') @args
}
```
## list-dupe-files
Batch script calculates and generates a report of dissimilar file data in the current working directory.
## eject-volume
Attempts to eject a pesky volume that won't eject safely. Such as external HDDs or USB drives.
## reset-filetype
Windows 10 had a frustrating way of handling filetype associations where if one made a mistake, ugly artifacts were left over in the UI. This script modifies the registry to nuke any artifacts related to a file type.
## virus-scan
Custom virus scan of critical locations.
### Locations:
- Browser cache:
    - Edge
    - Firefox
    - Chrome
- temp  
- email cache  
  - Windows Mail app
  - Outlook (legacy Outlook)
## `download_webpage.ps1`
Basic script taking as input a `URL` and an output `file name` to simplify downloading a file from the internet.