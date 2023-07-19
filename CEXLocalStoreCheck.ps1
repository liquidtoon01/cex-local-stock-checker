[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string]$ItemsToCheckFilePath,
    [Parameter(Mandatory=$true)]
    [string]$Latitude,
    [Parameter(Mandatory=$true)]
    [string]$Longitude, #https://www.latlong.net/
    [Parameter(Mandatory=$true)]
    [string]$StoresToCheckFilePath,
    [string]$PushoverToken,
    [string]$PushoverUser
)

#Items to check
[array] $items = Get-Content -Path $ItemsToCheckFilePath
#Stores to check
[array] $stores = Get-Content -Path $StoresToCheckFilePath

$wantedinstockpath = "wanted-games-stock.txt"
if(Test-Path $wantedinstockpath){}
else {New-Item -Name $wantedinstockpath }
$wantedinstock = Get-Content -Path $wantedinstockpath
[array] $summary = ""


function Send-PushoverNotification {
    Param(
      [Parameter(Mandatory=$true)]
      [string]$message
    )
    if($PushoverToken.Length -gt 1){
        $uri = "https://api.pushover.net/1/messages.json"
        $parameters = @{
            token = $PushoverToken
            user = $PushoverUser
            message = $message
        }
        Write-Host "Sending Pushover Notification: $message"
        $parameters | Invoke-RestMethod -Uri $uri -Method Post
    }
}

foreach ($item in $items){
    $neareststores = ConvertFrom-Json (Invoke-WebRequest "https://wss2.cex.uk.webuy.io/v3/boxes/$item/neareststores?latitude=$latitude&longitude=$longitude")
    $detail = ConvertFrom-Json (Invoke-WebRequest https://wss2.cex.uk.webuy.io/v3/boxes/$item/detail)
    $boxname = $detail.response.data.boxDetails.boxName

    foreach ($store in $stores){
        Write-Host "----------------------------------------------------------"
        Write-Host "Checking store $store for $boxname"
        $check = "$item, $store"
        if ($neareststores.response.data.nearestStores.storeName -eq $store){
            $WriteOutput ="$boxname is currently in stock locally at $store."
            
            if ($wantedinstock -notcontains $check) {
                Write-Host "Updating stock file with '$check'"
                Add-Content -Path $wantedinstockpath -Value $check
                Send-PushoverNotification -message "$boxname is now in stock at $store." #send pushover
            }
            else{
                Write-Host "No stock change for $check."
            }
        }
        elseif ($neareststores.response.data.nearestStores.storeName -ne $store) {
            $writeoutput = "$boxname is not in stock at $store."
            if ($wantedinstock -contains $check){
                Write-Host "Updating stock file REMOVING '$check'"
                Set-Content -Path $wantedinstockpath -Value (get-content -Path $wantedinstockpath | Select-String -Pattern $check -NotMatch)
                
                Send-PushoverNotification -message "$boxname is no longer in stock at $store."
                
            }
            
        }
        else {
            Write-Host $store "error"
        }
        $summary += $writeoutput
    }
      
    
}
Write-Host "------------------------Full Summary-----------------------" -ForegroundColor Yellow
    for ($i = 1; $i -lt $summary.Count; $i++) {
        if ($summary[$i].Contains("currently")) {
            Write-Host $summary[$i] -ForegroundColor Green
        }
        else {
            Write-Host $summary[$i] -ForegroundColor Red
        }
    } 
Write-Host "----------------------In Stock Summary---------------------" -ForegroundColor Yellow
    for ($i = 1; $i -lt $summary.Count; $i++) {
        if ($summary[$i].Contains("currently")) {
            Write-Host $summary[$i] -ForegroundColor Green
        }
        else {
        }
    } 