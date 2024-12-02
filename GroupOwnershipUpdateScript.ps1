$date = Get-Date -Format dd-MMM-yyyy-hh-mm
$Success_LogFile = "D:\Scripts\GroupOwnerUpdateScript\logs\GroupUpdate_Termed_Owner_Success_$date.txt"
$Failed_LogFile = "D:\Scripts\GroupOwnerUpdateScript\logs\GroupUpdate_Termed_Owner_Failed_$date.txt"
$Success= [System.Collections.ArrayList]::new()
$fail= [System.Collections.ArrayList]::new()

function Check_ManagedObjects {
	[CmdletBinding()]
	Param(
		[Parameter(Position = 0, Mandatory = $true)]
		[string]
		$NTID
	)
	$ManagedObjects = (Get-ADUser $NTID -Properties ManagedObjects).ManagedObjects
	$Results = Foreach ($obj in $ManagedObjects){
            if((Get-Adobject $obj).ObjectClass -eq "group"){
		    [pscustomobject]@{
			    Name = ($obj -split ',')[0].SubString(3)
			    Type = (Get-Adobject $obj).ObjectClass 
		}
	}
}
	$Results
}

function GroupOwnerUpdate {
    param(
        [Parameter(Mandatory=$true)]
        [array]$GroupNames,
        [Parameter(Mandatory=$true)]
        [string]$NewOwner,
        [Parameter(Mandatory=$true)]
        [string]$NewOwner_sam,
        [Parameter(Mandatory=$true)]
        [string]$NewOwnerDP,
        [Parameter(Mandatory=$true)]
        [string]$OldOwner,
        [Parameter(Mandatory=$true)]
        [string]$OldOwnerDP,
        $title,
        [Parameter(Mandatory=$true)]
        [string]$NewOwner_mail
    )

    try {
      [array]$GroupArray=  @()  
      foreach ($GroupName in $GroupNames)
        {
        $group = Get-ADGroup -Filter {Name -like $GroupName}
        Set-ADGroup -Identity $group -ManagedBy $NewOwner -Verbose 
        Write-Host "Displayname=$OldOwnerDP, NTID=$OldOwner | NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam  | $group Group owner updated successfully!" -BackgroundColor Green -ForegroundColor Black
        $Output =  "Displayname=$OldOwnerDP, NTID=$OldOwner | NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam  | $group Group owner updated successfully!" + $Date | Out-File $Success_LogFile -Append
        $GroupArray += ($group.DistinguishedName -join [Environment]::NewLine) + [Environment]::NewLine
        [void]$Success.Add([PSCustomObject]@{
                        "GroupName" = $GroupName
                        "NewOwner Title"= $title
                        "NewOwner" =  "NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam"
                        "OldOwner" =  "Displayname=$OldOwnerDP, NTID=$OldOwner"   
                        })
    
       }

    
            $mailmessage1 = @"

            <p> Hi $NewOwnerDP </b> </p>
 
            <p> You are receiving this email because you have been assigned as the new owner of the Group or Groups listed below:

            
            The groups mentioned below were previously under ownership of $OldOwnerDP (ntid= $OldOwner) , whose account has been terminated. Our automation selected you as the new owner because you are the manager of the original owner.</p>
            
          
            <p> However, if you do not think you are the right person to own the group and would like to designate someone as owner, please use the link below to submit a service request using <a href="https://amd.service-now.com/com.glideapp.servicecatalog_cat_item_view.do?v=1&sysparm_id=384931f6db571b04129e79caae961947&sysparm_link_parent=01ab72461b42fc9039902f8a2d4bcb11&sysparm_catalog=e0d08b13c3330100c8b837659bba8fb4&sysparm_catalog_view=catalog_default&sysparm_view=text_search">link</a></p>

            <br>
            <font color=blue><strong>$($GroupNames -join '<br>')</strong></font>
            <br/>


            <br>
            Regards, <br />
            IAM Team<br /><br />
            <br>
            <br>

            _____________ <br />
            <br /></font></h5>
"@



Send-MailMessage -Subject "Ownership updated for Groups owned by $OldOwnerDP" -SmtpServer "atlsmtp10.amd.com" -from "noreply@amd.com" -to $NewOwner_mail -body $mailmessage1 -BodyAsHtml     
  
 #Send-MailMessage -Subject "Ownership updated for Groups owned by $OldOwnerDP" -SmtpServer "atlsmtp10.amd.com" -from "noreply@amd.com" -to "mahsanba@amd.com" -body $mailmessage1 -BodyAsHtml   
    
}
    catch {
        Write-Error "Displayname=$OldOwnerDP, NTID=$OldOwner | NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam  |: $($_.Exception.Message)"
        Write-host  "Displayname=$OldOwnerDP, NTID=$OldOwner | NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam  |  Failed to update group owner: " -ForegroundColor red -BackgroundColor DarkMagenta
        $Output =   "Displayname=$OldOwnerDP, NTID=$OldOwner | NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam  |  Failed to update group owner: "+ $Date | Out-File $Failed_LogFile -Append
        [void]$fail.Add([PSCustomObject]@{
                        "NewOwner" =  "NewOwner_Displayname=$NewOwnerDP, Newowner_NTID=$NewOwner_sam"
                        "NewOwner Title"= $title
                        "OldOwner" =  "Displayname=$OldOwnerDP, NTID=$OldOwner"
                        "Reason"   =  "Failed to update group owner"  
                        })  
          }
}

function orgdetail{ 
 param  (
        $title,
        $AMDJobLevel
        )                        
   $VpLevelJobcode = 107,108,109,110,111,112,113,209,210,211                                    
   if($title -match "VP" -or $VpLevelJobcode -contains $AMDJobLevel)
     {
      return 1
     }
   else  
    {
     return 0
    }      
                                 
}

$termusers = Get-ADUser -Filter {AMDAccountStatus -eq "Terminated"} -Properties  samaccountname,Displayname,AMDLastMgr,AMDManager,ManagedObjects,title | ? {$_.ManagedObjects -ne $null} | Select-Object  samaccountname,AMDAccountStatus,AMDLastMgr,AMDManager,Displayname,title

foreach($user in $termusers)
{

$owner =   $user.samaccountname
$owner_DP= $user.Displayname

$grouplist= Check_ManagedObjects -NTID $owner | ? {$_.Type -eq 'group'} 

if(![string]::IsNullOrEmpty($grouplist))
{

$newowner_DN= $user.AMDManager
try
{
        $newowner=Get-ADUser -filter {((DistinguishedName -eq $newowner_DN) -and (AMDPriMaryUserID -like '*'))} -Properties samaccountname,name,DistinguishedName,mail ,title,Displayname,AMDJobLevel | select samaccountname ,name , DistinguishedName , mail , title ,AMDAccountStatus,Displayname,AMDJobLevel
        $newowner_DP=$newowner.name
        $newowner_NTID = $newowner.Samaccountname
        $newowner_mail=$newowner.mail
        $lock=1
}
catch
{       $lock=0
        Write-host "Displayname=$owner_DP, NTID=$owner | The user don't have manager information" -ForegroundColor red -BackgroundColor Black
        $Output =  "Displayname=$owner_DP, NTID=$owner | The user don't have manager information" + $Date | Out-File $Failed_LogFile -Append

        [void]$fail.Add([PSCustomObject]@{
                        "NewOwner" =  "---"
                        "NewOwner Title"= "---"
                        "OldOwner" =  "Displayname=$owner_DP, NTID=$owner" 
                        "Reason"   =  "User don't have manager information. Please check HRDB and update"  
                        })
}
if(![string]::IsNullOrEmpty($newowner) -and $lock -eq 1)
{
    $flag= orgdetail -title $newowner.title -AMDJobLevel $newowner.AMDJobLevel
    
    if($flag -eq 1){

        Write-host "Displayname=$owner_DP, NTID=$owner | NewOwner_Displayname=$newowner_DP, Newowner_NTID=$newowner_NTID  | Not updating ownership as the New Owner is a VP " -ForegroundColor red -BackgroundColor DarkYellow
        $Output =  "Displayname=$owner_DP, NTID=$owner | NewOwner_Displayname=$newowner_DP, Newowner_NTID=$newowner_NTID  | Not updating ownership as the New Owner is a VP " + $Date | Out-File $Failed_LogFile -Append

        [void]$fail.Add([PSCustomObject]@{
                        "NewOwner" =  "Displayname=$newowner_DP, NTID=$newowner_NTID"
                        "NewOwner Title"= $newowner.title
                        "OldOwner" =  "Displayname=$owner_DP, NTID=$owner"
                        "Reason"   =  "Not updating ownership as the New Owner is a VP"  
                        })
                   }
    else
    {
        if($newowner.AMDAccountStatus -ne "Terminated")
        {

              GroupOwnerUpdate -GroupNames $grouplist.name -NewOwner $newowner.DistinguishedName -NewOwner_sam $newowner_NTID -NewOwnerDP $newowner_DP -OldOwner $owner -OldOwnerDP $owner_DP -title $newowner.title -NewOwner_mail $newowner.mail
         }
        else
        {

        Write-host "Displayname=$owner_DP, NTID=$owner | NewOwner_Displayname=$newowner_DP, Newowner_NTID=$newowner_NTID  | New Owner is also Terminated " -ForegroundColor red
        $Output =  "Displayname=$owner_DP, NTID=$owner | NewOwner_Displayname=$newowner_DP, Newowner_NTID=$newowner_NTID  | New Owner is also Terminated " + $Date | Out-File $Failed_LogFile -Append
        
        [void]$fail.Add([PSCustomObject]@{
                        "NewOwner" =  "Displayname=$newowner_DP, NTID=$newowner_NTID"
                        "NewOwner Title"= $newowner.title
                        "OldOwner" =  "Displayname=$owner_DP, NTID=$owner"
                        "Reason"   =  "New Owner is a also Terminated"  
                        })

        }


    }

Clear-Variable newowner, newowner_DP , lock
}

Clear-Variable grouplist, owner ,flag , owner_DP

}

$Success | export-csv D:\Scripts\GroupOwnerUpdateScript\logs\Success_GroupOwnershipUpdateRecord_$date.csv
$fail |    export-csv D:\Scripts\GroupOwnerUpdateScript\logs\Fail_GroupOwnershipUpdateRecord_$date.csv

}