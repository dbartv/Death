# Death
Script to execute the DE part of the Brent Ozar Death method

#Script sections:
#Start script
#Run variables
#Output variables
#General variables
#Check if the SqlServer powershell module is installed
#Connect to server $Server and check if the database $DbName is found
#Get $Sp Version
#Delete the ouput table if it exists
#Execute sp_blitzindex and write output to $OutputDatbaseName
#Write General info
#Check if SQL is up and running longer than nr. of days defined by $MinDaysUptime
#Get sp_BlitzIndex result from the output database (unused indexes)
#Generate TSQL to drop unused indexes
#Remove obsolete data in the output database (unused indexes)
#Get sp_BlitzIndex from the database (duplicate indexes)
#Generate TSQL to remove duplicate indexes
#Remove obsolete data in the database (duplicate indexes)
#Get sp_BlitzIndex from the database (duplicate sort columns without include)
#Generate TSQL to remove indexes with the same leading fields and overlap in the included fields
#Get sp_BlitzIndex from the database (indexes with the same leading field as the clustered index)
#Generate TSQL to remove indexes with the same leading field as the clustered index
#Delete the ouput table if it exists
#Copy the output to the clipboard
