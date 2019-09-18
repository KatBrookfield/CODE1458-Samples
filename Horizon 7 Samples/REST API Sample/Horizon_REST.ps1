<#
.SYNOPSIS
Horizon 7.10 REST API Sample
Only works on Horizon 7.10 and Later

.NOTES
  Version:        1.0
  Author:         Chris Halstead - chalstead@vmware.com
  Creation Date:  8/20/2019
  Purpose/Change: Initial script development
  
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function LogintoHorizon {

#Get data and save to variables
$script:HorizonServer = Read-Host -Prompt 'Enter the Horizon Server Name'
$Username = Read-Host -Prompt 'Enter the Username'
$Password = Read-Host -Prompt 'Enter the Password' -AsSecureString
$domain = Read-Host -Prompt 'Enter the Domain'

#Retrieve oAuth2 Token
Write-Host "Getting JWT From: $HorizonServer"


$headers = @{Authorization = $basicAuthValue }
try {
    
    $sresult = Invoke-RestMethod -Method Post -Uri "https://$horizonserver/login" -Headers $headers 
}

catch {

  Write-Host "An error occurred when logging on to Horizon $_"
  break 
}

#Save the returned JSON Web Token to a Global Variable
$script:JW_Token = $sresult.access_token

Write-Host "Successfully Logged In"

  } 
Function GetUsers {

#Check if the user is logged in
if ([string]::IsNullOrEmpty($IDMToken))
    {
      write-host "You are not logged into IDM"
      break   
    }

Write-Host "Getting Workspace ONE Access Users on: $idmserver"

#Create header with oAuth2 Token
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{ Authorization = $bearerAuthValue }  

#Create variables
$allusers
$istartat = 1     
 
do {
 
try{$scimusers = Invoke-RestMethod -Method Get -Uri "https://$idmserver/SAAS/jersey/manager/api/scim/Users?startIndex=$istartat" -Headers $headers -ContentType "application/json"
        }
            catch {
                  Write-Host "An error occurred when getting users $_"
                  break 
                  }

$allusers = $scimusers.totalresults
$stotal = $stotal += $scimusers.itemsPerPage
write-host "Found $allusers users (returning $istartat to $stotal)"
$istartat += $scimusers.itemsPerPage
      
$scimusers.Resources | Format-table -AutoSize -Property @{Name = 'Username'; Expression = {$_.username}},@{Name = 'First Name'; Expression = {$_.name.givenname}},@{Name = 'Last Name'; Expression = {$_.name.familyname}}`
,@{Name = 'E-Mail'; Expression = {$_.emails.value}},@{Name = 'Active'; Expression = {$_.active}},@{Name = 'ID'; Expression = {$_.id}}

} until ($allusers -eq $stotal)
           
} 
Function GetGroups {
    #Connect to IDM
    Write-Host "Getting IDM Groups on: $idmserver"
    $bearerAuthValue = "Bearer $IDMToken"
    $headers = @{ Authorization = $bearerAuthValue }  
    
    try{
      $scimgroups = Invoke-RestMethod -Method Get -Uri "https://$idmserver/SAAS/jersey/manager/api/scim/Groups" -Headers $headers -ContentType "application/json"
       }
            
      catch {
              Write-Host "An error occurred when getting IDM groups $_"
              break 
            }

#Show returned data              
$scimgroups.Resources | Format-Table -autosize -Property active,username,name,emails
                                  
}          

Function GetApps {
#Connect to IDM
Write-Host "Getting apps on: $idmserver"
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{Authorization = $bearerAuthValue
             Accept = "application/vnd.vmware.horizon.manager.catalog.item.list+json"
            }  
          
try {
       

  $json = '{
    "includeAttributes": [
      "labels",
      "uiCapabilities",
      "authInfo"
    ],
    "includeTypes": [
      "Saml11",
      "Saml20",
      "WSFed12",
      "WebAppLink",
      "AnyApp"
    ],
    "nameFilter": "",
    "categories": [],
    "rootResource": false
  }'
  
$apps = Invoke-RestMethod -Method Post -Uri "https://$idmserver/SAAS/jersey/manager/api/catalogitems/search?startIndex=0&pageSize=50" -Headers $headers -Body $json -ContentType "application/vnd.vmware.horizon.manager.catalog.search+json"

    }
                  
      catch {
             Write-Host "An error occurred when getting IDM Apps $_"
             break 
            }
          
            $apps.items | Format-table -AutoSize -Property @{Name = 'Name'; Expression = {$_.name}},@{Name = 'Description'; Expression = {$_.description}},@{Name = 'Type'; Expression = {$_.catalogitemtype}
                                        
            }   
          
}       

Function GetCategories {

Write-Host "Getting categories on: $idmserver"

#Constuct header with oAuth2 Token
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{Authorization = $bearerAuthValue 
Accept = "application/vnd.vmware.horizon.manager.labels+json"}  
                        
try {
               
    $cats = Invoke-RestMethod -Method Get -Uri "https://$idmserver/SAAS/jersey/manager/api/labels" -Headers $headers -ContentType "application/vnd.vmware.horizon.manager.labels+json;charset=UTF-8"
              
    }
                                
    catch {
          Write-Host "An error occurred when getting IDM Apps $_"
          break 
          }
                        
$cats.items | Format-table -AutoSize -Property ID,Name
                                                      
}   

Function SendNotification {
 
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{Authorization = $bearerAuthValue}
$guid = New-GUID 

$usertoalert = Read-Host -Prompt 'Enter the User to Notify' 
                        
try {
               
    $user = Invoke-RestMethod -Method Get -Uri "https://$idmserver/SAAS/jersey/manager/api/scim/Users?filter=UserName%20eq%20""$usertoalert""" -Headers $headers
              
    }
                                        
    catch {
          Write-Host "An error occurred when searching for user $_"
          break 
          }

if ($user.totalresults -eq 0) 
{
  Write-Host "$usertoalert not found"
  break
}

$title = Read-Host -Prompt 'Enter the Title' 
$description = Read-Host -Prompt 'Enter the Message' 
                        
$theuser = $user.resources.id 

try {
  #Sends a message with a button and URL  
  $JSONMessage = '{"header": {"title": "' + $title + '"},"body": {"description": "' + $description +'"},"actions":[{"id":"' + $guid +'","label":"Notification API Docs","completed_label": "Page Visited","type":"POST", "primary": true,"allow_repeated": false,"url":{"href":"https://code.vmware.com/apis/402/workspace-one-notifications"},"action_key":"OPEN_IN"}]}'
  $message = Invoke-RestMethod -Method Post -Uri "https://$idmserver/ws1notifications/api/v1/users/$theuser/notifications" -Headers $headers -Body $JSONMessage -ContentType "application/json"               
}
                                   
  catch {
        Write-Host "An error occurred when sending message $_"
        break 
        }
           

$message.created_at | Format-Table
                                                      
}  
Function New_Category {

  $bearerAuthValue = "Bearer $IDMToken"
  $headers = @{Authorization = $bearerAuthValue
               Accept = "application/vnd.vmware.horizon.manager.label+json"
               }  
 
$newcatname = Read-Host -Prompt 'Enter the Category Name' 
               
    try {
               
$json = '{"name":"' + $newcatname + '"}'

    $cats = Invoke-RestMethod -Method Post -Uri "https://$idmserver/SAAS/jersey/manager/api/labels" -Headers $headers -Body $json -ContentType "application/vnd.vmware.horizon.manager.label+json;charset=UTF-8"
              
        }
                                
    catch {
          Write-Host "An error occurred when getting IDM Apps $_"
          break 
          }
                        
$cats.items | Format-table -AutoSize 
                                                      
}       

Function ServiceHealth {
             
Write-Host "Getting health of: $idmserver"
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{ Authorization = $bearerAuthValue }  
                        
try {
                          
      $health = Invoke-RestMethod -Method Get -Uri "https://$idmserver/SAAS/jersey/manager/api/system/health" -Headers $headers -ContentType "application/json"
              
    }
                                
catch {
      Write-Host "An error occurred when getting IDM Groups $_"
      break 
      }
                        
$health | Format-list 
                                                      
}          
              
Function CreateUser {
         
Write-Host "Getting IDM Groups on: $idmserver"
$bearerAuthValue = "Bearer $IDMToken"
$headers = @{ Authorization = $bearerAuthValue }  

$firstname = Read-Host -Prompt 'Input the users first name'
$lastname = Read-Host -Prompt 'Input the users last name'
$username = read-host -Prompt 'Input the User Name'
$emailaddress = Read-Host -Prompt 'Input the users email address'

$UserJson = '{"urn:scim:schemas:extension:workspace:1.0":{"domain":"System Domain"},"urn:scim:schemas:extension:enterprise:1.0":{},"schemas":["urn:scim:schemas:extension:workspace:mfa:1.0","urn:scim:schemas:extension:workspace:1.0","urn:scim:schemas:extension:enterprise:1.0","urn:scim:schemas:core:1.0"],"name":{"givenName":"' + $firstname + '","familyName":"'+ $lastname +'"},"userName":"' + $username + '","emails":[{"value":"' + $emailaddress + '"}]}'

  try{
    $scimcreate = Invoke-RestMethod -Method Post -Uri "https://$idmserver/SAAS/jersey/manager/api/scim/Users" -Headers $headers -Body $UserJson -ContentType "application/json;charset=UTF-8"
      }
  
        catch {
              Write-Host "An error occurred when creating a user $_"
              break
              }
                  $scimcreate.Resources | Format-Table -autosize -Property active,username,name,emails
}
function Show-Menu
  {
    param (
          [string]$Title = 'Workspace ONE Access API Menu'
          )
       Clear-Host
       Write-Host "================ $Title ================"
             
       Write-Host "Press '1' to Login to Workspace ONE Access"
       Write-Host "Press '2' for a list of Workspace ONE Access Users"
       Write-Host "Press '3' to create a Local User"
       Write-Host "Press '4' for a list of Apps"
       Write-Host "Press '5' for a list of the Categories"
       Write-Host "Press '6' to add a new Category"
       Write-Host "Press '7' for Workspace ONE Access Service Health"
       Write-Host "Press '8' to Send a Notification to a User"
       Write-Host "Press 'Q' to quit."
         }

#-----------------------------------------------------------[Execution]------------------------------------------------------------
do
 {
    Show-Menu
    $selection = Read-Host "Please make a selection"
    switch ($selection)
    {
    
    '1' {  

         LogintoIDM
    } 
    
    '2' {
   
         GetUsers

    } 
    
    '3' {
       
        CreateUser
      
    }

   
    '4' {
       
    GetApps
      
    
  }

  '5' {
       
GetCategories
  
}


'6' {
       
  New_Category
    
  }

'7' {
       
  ServiceHealth
    
  }

  '8' {
       
    SendNotification
      
    }

    }
    pause
 }
 until ($selection -eq 'q')


Write-Host "Finished"