<#Functions#>
#Function to check index options
#Function to check [include_column_names]
#Function to check [key_column_names_with_sort_order]   
#Function to generate TSQL code
#Function to generate TSQL code
#Function to output the TSQL code
#Function to remove obsolete records from the result set

<#General#>

<#Script#>
#Start script
#Run variables
#Output variables
#Check if the SqlServer powershell module is installed
#Check the SqlServer module version to avoid breaking change
#Connect to server $Server and check if the database $DbName exists
#Get the version number of dbo.sp_BlitzIndex
#Delete the ouput table if it exists
#Execute sp_blitzindex and write output to $OutputDatbaseName
#Write General info
#Check if SQL is up and running longer than the number of days defined by $MinDaysUptime        
#Get sp_BlitzIndex result from the output database (unused indexes)
#Generate TSQL to drop unused indexes
#Remove obsolete data in the output database (unused indexes)
#Get sp_BlitzIndex from the database (duplicate indexes)
#Generate TSQL to remove duplicate indexes
#Remove obsolete data in the database (duplicate indexes)
#Get sp_BlitzIndex from the database (duplicate sort columns without include)
#Generate TSQL to remove indexes with the same leading fields and overlap in the included fields
#Delete the ouput table if it exists
#Copy the output to the clipboard   
<#End of comment#>


#==================================================================================================
#Parameters
#==================================================================================================
Param(
    #Server where the database is located
    [Parameter(Mandatory = $True)] [string]$Server = $(Read-Host "Server name"),
    #Name of the database that you would like to examen
    [Parameter(Mandatory = $True)] [string]$DbName = $(Read-Host "Database name"),
    #Minimum number of days that the server should be up and running before suggesting index removals
    [Parameter(Mandatory = $False)] [int16]$MinDaysUptime = 7,
    #location of the sp_BlitzIndex sp on server $Server
    [Parameter(Mandatory = $False)] [string]$Sp_BlitzIndex = 'master.dbo.sp_BlitzIndex',
    #database where the output will be written
    [Parameter(Mandatory = $False)] [string]$OutputDatbaseName = $DbName,
    #schema in database $OutputDatbaseName where the output will be written
    [Parameter(Mandatory = $False)] [string]$OutputSchemaName = 'dbo',
    #table in database $OutputDatbaseName where the output will be written
    [Parameter(Mandatory = $False)] [string]$OutputTableName   = ('BlitzIndex_' + $DbName)
)
#==================================================================================================
#Function to check index options
#==================================================================================================
Function Test-IndexOptions ($Index){
  $Return = @{}
  $Return.add('Unique', ($Index.is_unique))
  Return $Return
}
#==================================================================================================
#Function to check [include_column_names]
#==================================================================================================
Function Compare-IncludeColumns ($IncludedColumns, $OtherIndex){
  #get the included columns of the ohter index
  $IncludedColumns2 = $OtherIndex.include_column_names.Split(',')
  $SortColumns2 = $OtherIndex.key_column_names_with_sort_order.Split(',')
  #If all the included columns appear also in another index, this index can be dropped.
  # as we have dropped duplicate indexes above, there's no danger of dropping the wrong index
  foreach($IncludedColumn in $IncludedColumns){
    if(($IncludedColumns2 -contains $IncludedColumn) -or ($SortColumns2 -contains $IncludedColumn)){
      $Return = $true
    }
    else{
      $Return = $false
      break
    }
  }
  Return $Return
}
#==================================================================================================
#Function to check [key_column_names_with_sort_order]
#==================================================================================================
Function Compare-SortColumns ($SortColumns, $OtherIndex){
  $i = 0
  #get the sort columns of the ohter index
  $SortColumns2 = $OtherIndex.key_column_names_with_sort_order.Split(',')
  #If all the sort columns appear also in the same order in the other index, then return $true to the script
  foreach($SortColumn in $SortColumns){
    if($SortColumns2[$i] -eq $SortColumn){
      $Return = $true
      $i++
    }
    else{
      $Return = $false
      break
    }
  }
  Return $Return
}
#==================================================================================================
#Function to generate TSQL code 
#==================================================================================================
Function New-TsqlStatementNarrow ($Result, $CreateScripts, $DropScripts, $Filter,$OtherIndex){
  $DropScript = ($Result.'Drop_TSQL'.Substring(2)) #Remove the comment '--' from the drop script
  $CreateScript = ('/*' +  ($Result.'Create_TSQL'.Substring(2)) + '*/') #Surround the create statement with a 'Block comment'
  $CreateScript = $CreateScript.Replace("ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);*/","ONLINE=OFF, MAXDOP=0);*/") #change the create script options
  $OtherIndexName = $OtherIndex.index_name
  [Void]$CreateScripts.Add("$CreateScript")
  [Void]$DropScripts.Add("/* Drop this index beacuese it's a narrower subset of: $OtherIndexName*/")
  [Void]$DropScripts.Add("$DropScript`r`n")
  [Void]$Filter.Add(([String]$Result.id + ",")) #Add the id's of dropped indexes to an array 
}
#==================================================================================================
#Function to generate TSQL code 
#==================================================================================================
Function New-TsqlStatement ($Result, $CreateScripts, $DropScripts, $Filter){
  $DropScript = ($Result.'Drop_TSQL'.Substring(2)) #Remove the comment '--' from the drop script
  $CreateScript = ('/*' +  ($Result.'Create_TSQL'.Substring(2)) + '*/') #Surround the create statement with a 'Block comment'
  $CreateScript = $CreateScript.Replace("ONLINE=?, SORT_IN_TEMPDB=?, DATA_COMPRESSION=?);*/","ONLINE=OFF, MAXDOP=0);*/") #change the create script options
  [Void]$CreateScripts.Add("$CreateScript")
  [Void]$DropScripts.Add("$DropScript")
  [Void]$Filter.Add(([String]$Result.id + ",")) #Add the id's of dropped indexes to an array 
}
#==================================================================================================
#Function to output the TSQL code 
#==================================================================================================
Function Write-TsqlStatement ($Output, $Message){
  Write-Output $Message
  [void]$Output.Add($Message)
  Write-Output $DropScripts
  Write-Output "/*UNDO SCRIPTS:*/"
  Write-Output $CreateScripts 
  [void]$Output.Add($DropScripts)
  [void]$Output.Add("`r`n/*Undo scripts:*/")
  [void]$Output.Add($CreateScripts)
}
#==================================================================================================
#Function to remove obsolete records from the result set
#==================================================================================================
Function Remove-Records ($Filter){
  $Query = "DELETE FROM [$OutputSchemaName].[$OutputTableName] WHERE [id] IN ($Filter)"
  Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -ErrorAction Stop
}
#==================================================================================================
#Start script
#==================================================================================================
#Remove-Variable -Name * -ErrorAction SilentlyContinue | Out-Null
clear-host
$StartDate = Get-Date
#==================================================================================================
#Run variables
#==================================================================================================
#$Server                = '' #Server with the database where sp_BlitzIndex should run
#$DbName                = '' #database where sp_BlitzIndex should run
#$MinDaysUptime         = 7 #Min nr of days that a server should be running when checking unused indexes
#$Sp_BlitzIndex                   = 'master.dbo.sp_BlitzIndex'
$ErrorActionPreference = 'Stop'
#==================================================================================================
#Output variables
#==================================================================================================
#$OutputDatbaseName = ''
#$OutputSchemaName  = 'dbo'
#$OutputTableName   = ('BlitzIndex_' + $DbName)
$Output            = (New-Object System.Collections.ArrayList)
#==================================================================================================
#Check if the SqlServer powershell module is installed
#==================================================================================================
try {
  Import-Module -Name SqlServer -ErrorAction Stop
  $Result = ((Get-Module -Name SqlServer -ErrorAction Stop).ExportedCommands).Keys | Where-Object {$PSItem -eq 'Invoke-Sqlcmd'}
  if($null -eq $Result) {
    Write-Error "The 'SqlServer' powershell module is needed to run this script. Please install the module prior to running this script." -ErrorAction Continue
                "https://learn.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver16"
    Exit
  }
}
catch {
  Throw
}
#==================================================================================================
#Check the SqlServer module version to avoid breaking change
#==================================================================================================
#https://github.com/microsoft/SQLServerPSModule/wiki/Secure-by-default:-breaking-changes-going-from-v21-to-v22
try{
  If($null -eq $PSDefaultParameterValues){
    $PSDefaultParameterValues = New-Object System.Collections.HashTable
  }
  $SQLModuleVersion = (Get-Module -Name SqlServer -ErrorAction Stop).Version
  $SqlModuleKey     = 'Invoke-SQLCmd:TrustServerCertificate'
  Write-Output "The version number of the SQL module is '$SqlModuleVersion'."
  if($SQLModuleVersion -ge [System.version]'22.0.0'){
    #If there's already an entry for 'Invoke-SQLCmd:TrustServerCertificate' set it to true (again)
    if($PSDefaultParameterValues.Count -eq 0){
      $PSDefaultParameterValues.Add($SqlModuleKey,$True)
    }
    elseif($PSDefaultParameterValues.ContainsKey($SqlModuleKey) -eq $true){
      $PSDefaultParameterValues[$SqlModuleKey] = $true
      Write-Output -Message "The value for $SqlModuleKey is set to 'true'."
    }
    #If there isn't an entry for 'Invoke-SQLCmd:TrustServerCertificate', add one
    else {
      $PSDefaultParameterValues.Add($SqlModuleKey,$True)
      Write-Output -Message "The key $SqlModuleKeyvalue is added with key value:'true'."
    }
  }
  #if the module version is lower then 22, check if the value for 'Invoke-SQLCmd:TrustServerCertificate' must be removed
  elseif($SQLModuleVersion -lt [System.version]'22.0.0'){
    if($PSDefaultParameterValues.ContainsKey($SqlModuleKey) -eq $true){
      $PSDefaultParameterValues[$SqlModuleKey]= $true
      Write-Output -Message "The key $SqlModuleKeyvalue is removed because the module version  $SQLModuleVersion  is lower then '22.0.0'."
    }
  }
}
catch {
  Throw
}
#==================================================================================================
#Connect to server $Server and check if the database $DbName exists
#==================================================================================================
$Query  = "SELECT [name] FROM [sys].[databases] WHERE [name] = '$DbName'"
try {
  $Result = (Invoke-Sqlcmd -ServerInstance $Server -Database master -Query $Query -ErrorAction Stop).name
  if($Result -ne $DbName){
    Write-Output "Database '$DbName' isn't found on SQL server '$Server'"
    Exit
  }
}
catch{
  Throw
}
#==================================================================================================
#Get the version number of dbo.sp_BlitzIndex
#==================================================================================================
#@Mode = 1 => Summarize
$Query  = "$Sp_BlitzIndex @DatabaseName = 'model', @Mode =1"
try {
  $Version = (Invoke-Sqlcmd -ServerInstance $Server -Database master -Query $Query -ErrorAction Stop)[1]
}
catch{
  Throw
}
#==================================================================================================
#Delete the ouput table if it exists
#==================================================================================================
$Query = "IF EXISTS  
	          (SELECT * FROM sys.tables t  
             INNER JOIN sys.schemas s ON t.[schema_id] = s.[schema_id] 
             WHERE t.[name] = '$OutputTableName' AND s.[name] = '$OutputSchemaName')
          DROP TABLE [$OutputSchemaName].[$OutputTableName]"

try {
  Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -ErrorAction Stop
}
catch{
  Throw
}
#==================================================================================================
#Execute sp_blitzindex and write output to $OutputDatbaseName
#==================================================================================================
$Query = "$Sp_BlitzIndex @DatabaseName = '$DbName', @Mode = 2, @outputDatabaseName = '$OutputDatbaseName',
           @OutputTableName = '$OutputTableName', @OutputSchemaName = '$OutputSchemaName'"

try {
  Invoke-Sqlcmd -ServerInstance $Server -Database master -Query $Query -ErrorAction Stop
}
catch {
  Throw
}
#==================================================================================================
#Write General info
#==================================================================================================
$Date = Get-Date
$User = ($env:USERNAME).ToUpper()
$Text = "/*
Date:$Date
User:$User
Server:$Server
Database:$DbName
$Version

This script will generate drop and undo scripts for:
-Indexes with 0 reads (If the server is up and running for more then $MinDaysUptime days)
-Duplicate indexes
-Indexes with a narrower copy

*/

"
Write-Output $Text
[Void]$Output.Add($Text)
#==================================================================================================
#Check if SQL is up and running longer than the number of days defined by $MinDaysUptime
#==================================================================================================
$Query = "SELECT DATEDIFF(dd,sqlserver_start_time,GETDATE())  AS  [DaysUp] from sys.dm_os_sys_info"

try {
  $DaysUp = (Invoke-Sqlcmd -ServerInstance $Server -Database master -Query $Query -ErrorAction Stop).DaysUp
  if($DaysUp -lt $MinDaysUptime){
    $BoolDaysUp = $false
    Write-Output "/*$Server is up for $DaysUp days. $MinDaysUptime days is requested for an accurate results about index usage.
                  The part for the 'unused indexes will be skipped.*/`r`n"
    [void]$Output.Add("`r`n/*$Server is up for $DaysUp days. $MinDaysUptime days is requested for an accurate results about index usage.")
    [void]$Output.Add("The part for the 'unused indexes will be skipped.*/`r`n")
  }
  else{
    $BoolDaysUp = $true
    Write-Output "/*`r`n$Server is up for $DaysUp days. Index usage will be checked.`r`n*/`r`n"
    [void]$Output.Add("`r`n/*`r`n$Server is up for $DaysUp days. Index usage will be checked.`r`n*/`r`n")
  }
}
catch{
  Throw
}
#==================================================================================================
#Get sp_BlitzIndex result from the output database (unused indexes)
#==================================================================================================
if($BoolDaysUp -eq $true){
  #This query will return only indexes that haven't been modified for the last $MinDaysUptime days
  $Query = "SELECT [id]
                ,[schema_name]
                ,[table_name]
                ,[index_name]
                ,[Drop_Tsql]
                ,[Create_Tsql]
          FROM [$OutputSchemaName].[$OutputTableName]
          WHERE 
                [index_id] > 1 AND 
                [index_usage_summary] like 'Reads: 0 Writes%' AND 
                [is_unique_constraint] = 0 AND 
                [index_definition] NOT LIKE '\[UNIQUE\]%' {escape '\'} AND
                [is_primary_key] = 0 AND
                DATEDIFF(dd, modify_date,run_datetime) > $MinDaysUptime"
  try {
    $Results = Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -ErrorAction Stop
    $Results = $Results | Sort-Object -Property 'Schema_Name', 'Object_Name', 'Index_Name'
  }
  catch{
    Throw
  }
}
#==================================================================================================
#Generate TSQL to drop unused indexes
#==================================================================================================
$CreateScripts = (New-Object System.Collections.ArrayList)
$DropScripts   = (New-Object System.Collections.ArrayList)
$Filter        = (New-Object System.Collections.ArrayList)

if(($BoolDaysUp -eq $true) -and ($null -ne $Results)){
  foreach($Result in $Results){
    New-TsqlStatement $Result $CreateScripts $DropScripts $Filter
  }
  if($DropScripts.count -gt 0){
    $Message = "/*`r`nDrop indexe(s) with 0 reads`r`n*/`r`n"
    Write-TsqlStatement $Output $Message 
  }
}
#==================================================================================================
#Remove obsolete data in the output database (unused indexes)
#==================================================================================================
#Remove the information regarding the dropped indexes from the output database.
#These indexes should no longer be taken into account further down the script
if($Filter.count -gt 0){
  $LastItem = $Filter[-1].Substring(0,$Filter[-1].Length-1) #Remove the comma from the last item in the array list
  $Filter.RemoveAt($Filter.Count-1) #remove the last item from the array list
  [void]$Filter.Add($LastItem) #add the string without the comma to the list
  Remove-Records -Filter $Filter
}
#==================================================================================================
#Get sp_BlitzIndex from the database (duplicate indexes)
#==================================================================================================
$Query = "
WITH cte
/*Get a distinct list of duplicate indexes */
     AS (SELECT DISTINCT t1.[id],
                         t1.[key_column_names_with_sort_order],
                         t1.[schema_name],
                         t1.[table_name],
                         t1.[drop_tsql],
                         t1.[create_tsql],
                         t1.[include_column_names],
                         t1.[filter_definition],
                         t1.[is_unique_constraint],
                         t1.[is_disabled],
                         t1.[is_hypothetical]
         FROM   [$OutputSchemaName].[$OutputTableName] t1 INNER JOIN
                [$OutputSchemaName].[$OutputTableName] t2  
                ON t1.[table_name] = t2.[table_name]
                AND t1.[schema_name] = t2.[schema_name]
                AND t1.id <> t2.id
         WHERE  t1.[schema_name] = t2.[schema_name]
                AND t1.[table_name] = t2.[table_name]
                AND t1.[filter_definition] = t2.[filter_definition]
                AND t1.[is_unique_constraint] = t2.[is_unique_constraint]
                AND t1.[is_disabled] = t2.[is_disabled]
                AND t1.[is_hypothetical] = t2.[is_hypothetical]
                AND t1.[include_column_names] = t2.[include_column_names]
                AND t1.[key_column_names_with_sort_order] = t2.[key_column_names_with_sort_order]
                AND t1.[is_primary_key] = t2.[is_primary_key]
                --AND t1.object_type = 'NonClustered'
)
/*Add a row number */
,CTE2 AS
(
SELECT [id],
       [key_column_names_with_sort_order],
       [schema_name],
       [table_name],
       [drop_tsql],
       [create_tsql],
       [include_column_names],
       [filter_definition],
       [is_unique_constraint],
       [is_disabled],
       [is_hypothetical],
        Row_number()
              OVER (
              partition BY [schema_name], [table_name],
              [filter_definition],
              [is_unique_constraint], [is_disabled],
              [include_column_names],
              [is_hypothetical],
              [key_column_names_with_sort_order]
              ORDER BY id DESC ) row_num
FROM   cte)
/*Get all the indexes with row_num <> 1, these should be deleted */
SELECT [id],
       [key_column_names_with_sort_order],
       [schema_name],
       [table_name],
       [drop_tsql],
       [create_tsql],
       [include_column_names],
       [filter_definition],
       [is_unique_constraint],
       [is_disabled],
       [is_hypothetical]
FROM   cte2 WHERE row_num <> 1"
try {
  $Results = Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -ErrorAction Stop
}
catch{
  Throw
}
#==================================================================================================
#Generate TSQL to remove duplicate indexes
#================================================================================================== 
$CreateScripts = (New-Object System.Collections.ArrayList)
$DropScripts   = (New-Object System.Collections.ArrayList)
$Filter        = (New-Object System.Collections.ArrayList)

foreach($Result in $Results){
  New-TsqlStatement $Result $CreateScripts $DropScripts $Filter
}
if($DropScripts.count -gt 0){
  $Message = "`r`n/*`r`nDrop duplicate indexe(s)`r`n*/`r`n"
  Write-TsqlStatement $Output $Message
}
#==================================================================================================
#Remove obsolete data in the database (duplicate indexes)
#==================================================================================================
#Remove the information regarding the dropped indexes from the output database.
#These indexes should no longer be taken into account further down the script
if($Filter.count -gt 0){
  $LastItem = $Filter[-1].Substring(0,$Filter[-1].Length-1) #Remove the comma from the last item in the array list
  $Filter.RemoveAt($Filter.Count-1) #remove the last item from the array list
  [void]$Filter.Add($LastItem) #add the string without the comma to the list
  Remove-Records -Filter $Filter
}
#==================================================================================================
#Get sp_BlitzIndex from the database (duplicate sort columns without include)
#==================================================================================================
#Get nonclustered indexes where there's more then 1 index on a table
$Query = "SELECT t1.[id],
                  t1.[key_column_names_with_sort_order],
	                /*Below line is to concatenate the inlcude_column_names and secret colum, the secret column starts with '[1 KEY]' and must be removed with the substring expression
					        If there are no included columns, just select the secret column*/
					        CASE t1.include_column_names 
					        WHEN '' THEN
					          (Substring ((t1.[secret_columns]), ((CHARINDEX(']',t1.[secret_columns],0)) + 1), (LEN(t1.[secret_columns])))) 
					         ELSE
					          (CONCAT(t1.[include_column_names],',',(Substring ((t1.[secret_columns]), ((CHARINDEX(']',t1.[secret_columns],0)) + 1), (LEN(t1.[secret_columns])))))) 
					        END AS [include_column_names], 
                  t1.[index_name],
                  t1.[schema_name],
                  t1.[table_name],
                  t1.[drop_tsql],
                  t1.[create_tsql],
                  t1.[is_unique_constraint],
                  t1.object_type
          FROM   [$OutputSchemaName].[$OutputTableName] t1 
          WHERE  (SELECT Count(*)
                  FROM   [$OutputSchemaName].[$OutputTableName] t2
                  WHERE  t2.object_type = 'NonClustered'
                          AND t1.[schema_name] = t2.[schema_name]
                          AND t1.[table_name] = t2.[table_name]
                  GROUP  BY table_name) > 1
                  AND t1.object_type = 'NonClustered'"
try {
  $Results = Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -OutputAs DataTables -ErrorAction Stop
}
catch{
  Throw
}
#==================================================================================================
#Generate TSQL to remove indexes with the same leading fields and overlap in the included fields
#================================================================================================== 
$CreateScripts = (New-Object System.Collections.ArrayList)
$DropScripts = (New-Object System.Collections.ArrayList)
$Filter = (New-Object System.Collections.ArrayList)
#Group the result by schema_name, table_name and key_column_names_with_sort_order
#This groups the indexes on given table with the same columns in the 'index key columns'
$Groups = $Results | Group-Object {$PsItem.schema_name} ,{$PsItem.table_name} 
foreach($Group in $Groups){
  foreach($Item in $Group.Group){
    $Result = Test-IndexOptions $Item 
    $SortColumns =  $item.key_column_names_with_sort_order.Split(',')
    #get other indexes in the same group
    $OtherIndexes = $Group.Group | Where-Object {($PsItem.Id -ne $Item.Id) -and ($PsItem.is_unique_constraint -eq $Result.Unique)}
    foreach($OtherIndex in $OtherIndexes){
      $Drop = Compare-SortColumns $SortColumns $OtherIndex      
      if($Drop -eq $true){
        $IncludedColumns = $item.include_column_names.Split(',')
        $Drop = Compare-IncludeColumns $IncludedColumns $OtherIndex
        if($Drop -eq $true){
          New-TsqlStatementNarrow $Item $CreateScripts $DropScripts $Filter $OtherIndex
          Break
        }
      }
    }
  }
}
if($DropScripts.count -gt 0){
  $Message = "`r`n/*`r`nDrop indexe(s) with the same 'Index key columns' and overlapping 'Included columns'`r`n*/`r`n"
  Write-TsqlStatement $Output $Message
}
#==================================================================================================
#Delete the ouput table if it exists
#==================================================================================================
$Query = "IF EXISTS  
	          (SELECT * FROM sys.tables t  INNER JOIN sys.schemas s ON 
	          t.[schema_id] = s.[schema_id] WHERE t.[name] = '$OutputTableName' AND s.[name] = '$OutputSchemaName')
          DROP TABLE [$OutputSchemaName].[$OutputTableName]"
try {
  Invoke-Sqlcmd -ServerInstance $Server -Database $OutputDatbaseName -Query $Query -ErrorAction Stop
}
catch{
  Throw
}
#==================================================================================================
#Copy the output to the clipboard
#==================================================================================================
$Output | Set-Clipboard
$EndDate = Get-Date
New-TimeSpan -start $StartDate -End $EndDate