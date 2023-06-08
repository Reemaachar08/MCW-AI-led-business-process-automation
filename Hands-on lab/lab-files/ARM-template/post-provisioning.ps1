$subscriptionId = (Get-AzContext).Subscription.Id
$dest = (Get-Item .).Parent.FullName
$resourceGroupName = (Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*RG01-*" }).ResourceGroupName
$storageAccountName = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName).StorageAccountName
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName).Value[0]
$containerName = "claimstraining"
$containerSAS = New-AzStorageContainerSASToken -Context (New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey) -ExpiryTime (Get-Date).AddSeconds(3600) -Name $containerName -Permission rw
$containerSASURI = "https://$storageAccountName.blob.core.windows.net/$containerName$($containerSAS.TrimStart('?'))"
$localPath = "C:\MCW\MCW-main\Hands-on lab\lab-files\claims-forms"

Write-Host "Uploading training data to Azure Storage"
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
Get-ChildItem -Path $localPath -File -Exclude *test*.* | ForEach-Object {
    Set-AzStorageBlobContent -Context $destinationContext -Container $containerName -File $_.FullName -Force
}

Write-Host "Deploying Document Processing Azure Function App"
$functionAppName = (Get-AzFunctionApp -ResourceGroupName $resourceGroupName).Name
$zipArchiveFullPath = "C:\MCW\MCW-main\Hands-on lab\lab-files\source-azure-functions\DocumentProcessing.zip"
$functionApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionAppName
Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionAppName -ArchivePath $zipArchiveFullPath -Force
Set-AzResource -ResourceId (Get-AzFunctionApp -ResourceGroupName $resourceGroupName -Name $functionAppName).Id -PropertyObject @{
    "ScmType" = "LocalGit"
} -Force

Write-Host "Deploying Hospital Portal"
$webAppName = (Get-AzWebApp -ResourceGroupName $resourceGroupName | Where-Object Name -like 'contoso-portal*').Name
$zipArchiveFullPath = "C:\MCW\MCW-main\Hands-on lab\lab-files\source-hospital-portal\contoso-web.zip"
Publish-AzWebapp -ResourceGroupName $resourceGroupName -Name $webAppName -ArchivePath $zipArchiveFullPath

Write-Host "Environment setup complete." -ForegroundColor Green
