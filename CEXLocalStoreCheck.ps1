[CmdletBinding()]
Param (
    #[Parameter(Mandatory=$true)]
    [string]$ItemsToCheckFilePath = ".\items-to-check.txt",
    #[Parameter(Mandatory=$true)]
    [string]$Latitude = "54.953800",
    #[Parameter(Mandatory=$true)]
    [string]$Longitude = "-1.455030", #https://www.latlong.net/
    #[Parameter(Mandatory=$true)]
    [string]$StoresToCheckFilePath = "stores-to-check.txt",
    [string]$PushoverToken = "aab2nv99jg36mgjthj29gdmjiyx5o3",
    [string]$PushoverUser = "uzdp3zaqsg5uxfz1ua5gviyyq4j2so",
    [string[]]$SendSummaryNotificationOn=@()
)
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
#Items to check
[array] $items = Get-Content -Path $ItemsToCheckFilePath
$ErrorActionPreference = 'SilentlyContinue'
foreach ($i in $items) { ($items[$items.IndexOf($i)] = $i.SubString(0, $i.IndexOf('#'))).trim() } 
foreach ($i in $items) { ($items[$items.IndexOf($i)] = $i.SubString(0, $i.IndexOf(' '))).trim() }
Clear-Host 
$ErrorActionPreference = 'Break'
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
      [string]$message,
      [string]$item
    )
    if($PushoverToken.Length -gt 1){
        $uri = "https://api.pushover.net/1/messages.json"
        $parameters = @{
            token = $PushoverToken
            user = $PushoverUser
            message = $message
            url = "https://uk.webuy.com/product-detail/?id=$item"
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
                Send-PushoverNotification -message "$boxname is now in stock at $store." -item $item #send pushover
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
                
                Send-PushoverNotification -message "$boxname is no longer in stock at $store." -item $item
                
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
    # * optional send on specific days summary
    $NotificationSentCheck = "summary-sent-today.txt"
    $NotificationSent = Get-Content -Path $NotificationSentCheck -ErrorAction SilentlyContinue

    if($SendSummaryNotificationOn.Length -gt 0){

        if(Test-Path $NotificationSentCheck){}
        else {New-Item -Name $NotificationSentCheck}    

        if((get-date).DayOfWeek -in $SendSummaryNotificationOn -and !$NotificationSent){
            $summarynotification = "----- In Stock Summary -----`r`n"
            for ($i = 1; $i -lt $summary.Count; $i++) {
                if ($summary[$i].Contains("currently")) {
                    $summarynotification = $summarynotification +  $summary[$i] + "`r`n------------------------------`r`n"
                    Add-Content -Path $NotificationSentCheck -Value "1"
                }
                else {  
                }
            }
            Send-PushoverNotification -message $summarynotification
        }
        else{
            Clear-Content $NotificationSentCheck 
        }
    }