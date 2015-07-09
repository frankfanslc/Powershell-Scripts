function Connect-Exchange
{ 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [PSCredential]$Credentials
    )  
 	Begin
		 {
		## Load Managed API dll  
		###CHECK FOR EWS MANAGED API, IF PRESENT IMPORT THE HIGHEST VERSION EWS DLL, ELSE EXIT
		$EWSDLL = (($(Get-ItemProperty -ErrorAction SilentlyContinue -Path Registry::$(Get-ChildItem -ErrorAction SilentlyContinue -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Exchange\Web Services'|Sort-Object Name -Descending| Select-Object -First 1 -ExpandProperty Name)).'Install Directory') + "Microsoft.Exchange.WebServices.dll")
		if (Test-Path $EWSDLL)
		    {
		    Import-Module $EWSDLL
		    }
		else
		    {
		    "$(get-date -format yyyyMMddHHmmss):"
		    "This script requires the EWS Managed API 1.2 or later."
		    "Please download and install the current version of the EWS Managed API from"
		    "http://go.microsoft.com/fwlink/?LinkId=255472"
		    ""
		    "Exiting Script."
		    exit
		    } 
  
		## Set Exchange Version  
		$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP2  
		  
		## Create Exchange Service Object  
		$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)  
		  
		## Set Credentials to use two options are availible Option1 to use explict credentials or Option 2 use the Default (logged On) credentials  
		  
		#Credentials Option 1 using UPN for the windows Account  
		#$psCred = Get-Credential  
		$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString())  
		$service.Credentials = $creds      
		#Credentials Option 2  
		#service.UseDefaultCredentials = $true  
		 #$service.TraceEnabled = $true
		## Choose to ignore any SSL Warning issues caused by Self Signed Certificates  
		  
		## Code From http://poshcode.org/624
		## Create a compilation environment
		$Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
		$Compiler=$Provider.CreateCompiler()
		$Params=New-Object System.CodeDom.Compiler.CompilerParameters
		$Params.GenerateExecutable=$False
		$Params.GenerateInMemory=$True
		$Params.IncludeDebugInformation=$False
		$Params.ReferencedAssemblies.Add("System.DLL") | Out-Null

$TASource=@'
  namespace Local.ToolkitExtensions.Net.CertificatePolicy{
    public class TrustAll : System.Net.ICertificatePolicy {
      public TrustAll() { 
      }
      public bool CheckValidationResult(System.Net.ServicePoint sp,
        System.Security.Cryptography.X509Certificates.X509Certificate cert, 
        System.Net.WebRequest req, int problem) {
        return true;
      }
    }
  }
'@ 
		$TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
		$TAAssembly=$TAResults.CompiledAssembly

		## We now create an instance of the TrustAll and attach it to the ServicePointManager
		$TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
		[System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

		## end code from http://poshcode.org/624
		  
		## Set the URL of the CAS (Client Access Server) to use two options are availbe to use Autodiscover to find the CAS URL or Hardcode the CAS to use  
		  
		#CAS URL Option 1 Autodiscover  
		$service.AutodiscoverUrl($MailboxName,{$true})  
		Write-host ("Using CAS Server : " + $Service.url)   
		   
		#CAS URL Option 2 Hardcoded  
		  
		#$uri=[system.URI] "https://casservername/ews/exchange.asmx"  
		#$service.Url = $uri    
		  
		## Optional section for Exchange Impersonation  
		  
		#$service.ImpersonatedUserId = new-object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $MailboxName) 
		if(!$service.URL){
			throw "Error connecting to EWS"
		}
		else
		{		
			return $service
		}
	}
}
function Create-Contact 
{ 
    [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
 		[Parameter(Position=1, Mandatory=$true)] [string]$DisplayName,
		[Parameter(Position=2, Mandatory=$true)] [string]$FirstName,
		[Parameter(Position=3, Mandatory=$true)] [string]$LastName,
		[Parameter(Position=4, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=5, Mandatory=$false)] [string]$CompanyName,
		[Parameter(Position=6, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=7, Mandatory=$false)] [string]$Department,
		[Parameter(Position=8, Mandatory=$false)] [string]$Office,
		[Parameter(Position=9, Mandatory=$false)] [string]$BusinssPhone,
		[Parameter(Position=10, Mandatory=$false)] [string]$MobilePhone,
		[Parameter(Position=11, Mandatory=$false)] [string]$HomePhone,
		[Parameter(Position=12, Mandatory=$false)] [string]$IMAddress,
		[Parameter(Position=13, Mandatory=$false)] [string]$Street,
		[Parameter(Position=14, Mandatory=$false)] [string]$City,
		[Parameter(Position=15, Mandatory=$false)] [string]$State,
		[Parameter(Position=16, Mandatory=$false)] [string]$PostalCode,
		[Parameter(Position=17, Mandatory=$false)] [string]$Country,
		[Parameter(Position=18, Mandatory=$false)] [string]$JobTitle,
		[Parameter(Position=19, Mandatory=$false)] [string]$Notes,
		[Parameter(Position=20, Mandatory=$false)] [string]$Photo,
		[Parameter(Position=21, Mandatory=$false)] [string]$FileAs,
		[Parameter(Position=22, Mandatory=$false)] [string]$WebSite,		
		[Parameter(Position=23, Mandatory=$false)] [string]$Folder
		
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		if($service.URL){
			$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
			$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
			$ParentFolderIds = [Activator]::CreateInstance($type)
			$ParentFolderIds.Add($Contacts.Id)
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
			$createContactOkay = $false
			if($Error.Count -eq 0){
				if ($ncCol.Count -eq 0) {
					$createContactOkay = $true;	
				}
				else{
					foreach($Result in $ncCol){
						if($Result.Contact -eq $null){
							Write-host "Contact already exists " + $Result.Contact.DisplayName
							throw ("Contact already exists")
						}
						else{
							$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $EmailAddress
							$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
							if ($ncCola.Count -eq 0) {  
								$createContactOkay = $true;		
							}
							else
							{
								Write-Host -ForegroundColor  Red ("Number of existing Contacts Found " + $ncCola.Count)
								foreach($Result in $ncCola){
									Write-Host -ForegroundColor  Red ($ncCola.Mailbox.Name)
								}
								throw ("Contact already exists")
							}
						}
					}
				}
				if($createContactOkay){
					$Contact = New-Object Microsoft.Exchange.WebServices.Data.Contact -ArgumentList $service 
					#Set the GivenName
					$Contact.GivenName = $FirstName
					#Set the LastName
					$Contact.Surname = $LastName
					#Set Subject  
					$Contact.Subject = $DisplayName
					$Contact.FileAs = $DisplayName
					$Contact.CompanyName = $CompanyName
					$Contact.DisplayName = $DisplayName
					$Contact.Department = $Department
					$Contact.OfficeLocation = $Office
					$Contact.CompanyName = $CompanyName
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone] = $BusinssPhone
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone] = $MobilePhone
					$Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone] = $HomePhone
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business] = New-Object  Microsoft.Exchange.WebServices.Data.PhysicalAddressEntry
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street = $Street
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State = $State
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City = $City
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion = $Country
					$Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode = $PostalCode
					$Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1] = $EmailAddress
					$Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] = $IMAddress 
					$Contact.FileAs = $FileAs
					$Contact.BusinessHomePage = $WebSite
					#Set any Notes  
					$Contact.Body = $Notes
					$Contact.JobTitle = $JobTitle
					if($Photo){
						$fileAttach = $Contact.Attachments.AddFileAttachment($Photo)
						$fileAttach.IsContactPhoto = $true
					}
			   		$Contact.Save($Contacts.Id)				
					Write-Host ("Contact Created")
				}
			}
		}
	}
}
function Get-Contact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=4, Mandatory=$false)] [switch]$SearchGal
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($SearchGal)
		{
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
			if($Error.Count -eq 0){
				foreach($Result in $ncCol){				
					Write-Output $ncCol.Contact
				}
			}
		}
		else
		{
			if($Folder){
				$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
			}
			else{
				$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
			}
			if($service.URL){
				$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
				$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
				$ParentFolderIds = [Activator]::CreateInstance($type)
				$ParentFolderIds.Add($Contacts.Id)
				$Error.Clear();
				$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
				if($Error.Count -eq 0){
					if ($ncCol.Count -eq 0) {
						Write-Host -ForegroundColor Yellow ("No Contact Found")		
					}
					else{
						foreach($Result in $ncCol){
							if($Result.Contact -eq $null){
								Write-Output $Result
							}
							else{
								$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $EmailAddress
								$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
								if ($ncCola.Count -eq 0) {  
									Write-Host -ForegroundColor Yellow ("No Contact Found")			
								}
								else
								{
									Write-Host ("Number of matchine Contacts Found " + $ncCola.Count)
									$rtCol = @()
									foreach($aResult in $ncCola){
										$rtCol += [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$aResult[0].Mailbox.Id) 
									}
									Write-Output $rtCol
								}
							}
						}
					}
				}
				

				
			}
		}
	}
}
function Delete-Contact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [switch]$force,
		[Parameter(Position=4, Mandatory=$false)] [string]$Folder
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		if($service.URL){
			$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
			$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
			$ParentFolderIds = [Activator]::CreateInstance($type)
			$ParentFolderIds.Add($Contacts.Id)
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
			if($Error.Count -eq 0){
				if ($ncCol.Count -eq 0) {
					Write-Host -ForegroundColor Yellow ("No Contact Found")		
				}
				else{
					foreach($Result in $ncCol){
						if($Result.Contact -eq $null){
							$contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$Result[0].Mailbox.Id) 
							if($force){
								$contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete)  
								Write-Host ("Contact Deleted")
							}
							else{
							    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""  
	                            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""  
	                            $all = new-Object System.Management.Automation.Host.ChoiceDescription "&All","";  
	                            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no,$all)  
	                            $message = "Do you want to Delete contact with DisplayName " + $contact.DisplayName + " : Subject-" + $contact.Subject  
	                            $result = $Host.UI.PromptForChoice($caption,$message,$choices,0)  
	                            if($result -eq 0) {                       
	                                $contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete) 
									Write-Host ("Contact Deleted")
	                            } 
								else{
									Write-Host ("No Action Taken")
								}
								
							}
						}
						else{
							$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $EmailAddress
							$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
							if ($ncCola.Count -eq 0) {  
								Write-Host -ForegroundColor Yellow ("No Contact Found")			
							}
							else
							{
								Write-Host ("Number of matchine Contacts Found " + $ncCola.Count)
								$rtCol = @()
								foreach($aResult in $ncCola){
									$contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$aResult[0].Mailbox.Id) 
									if($force){
										$contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete)  
										Write-Host ("Contact Deleted")
									}
									else{
									    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes",""  
			                            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No",""  
			                            $all = new-Object System.Management.Automation.Host.ChoiceDescription "&All","";  
			                            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no,$all)  
			                            $message = "Do you want to Delete contact with DisplayName " + $contact.DisplayName + " : Subject-" + $contact.Subject  
			                            $result = $Host.UI.PromptForChoice($caption,$message,$choices,0)  
			                            if($result -eq 0) {                       
			                                $contact.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete) 
											Write-Host ("Contact Deleted")
			                            } 
										else{
											Write-Host ("No Action Taken")
										}
										
									} 
								}								
							}
						}
					}
				}
			}	
			
		}
	}
}
function Make-UniqueFileName{
    param(
		[Parameter(Position=0, Mandatory=$true)] [string]$FileName
	)
	Begin
	{
	
	$directoryName = [System.IO.Path]::GetDirectoryName($FileName)
    $FileDisplayName = [System.IO.Path]::GetFileNameWithoutExtension($FileName);
    $FileExtension = [System.IO.Path]::GetExtension($FileName);
    for ($i = 1; ; $i++){
            
            if (![System.IO.File]::Exists($FileName)){
				return($FileName)
			}
			else{
					$FileName = [System.IO.Path]::Combine($directoryName, $FileDisplayName + "(" + $i + ")" + $FileExtension);
			}                
            
			if($i -eq 10000){throw "Out of Range"}
        }
	}
}

function Get-ContactFolder{
	param (
	        [Parameter(Position=0, Mandatory=$true)] [string]$FolderPath,
			[Parameter(Position=1, Mandatory=$true)] [string]$SmptAddress,
			[Parameter(Position=2, Mandatory=$true)] [Microsoft.Exchange.WebServices.Data.ExchangeService]$service
		  )
	process{
		## Find and Bind to Folder based on Path  
		#Define the path to search should be seperated with \  
		#Bind to the MSGFolder Root  
		$folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot,$SmptAddress)   
		$tfTargetFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)  
		#Split the Search path into an array  
		$fldArray = $FolderPath.Split("\") 
		 #Loop through the Split Array and do a Search for each level of folder 
		for ($lint = 1; $lint -lt $fldArray.Length; $lint++) { 
	        #Perform search based on the displayname of each folder level 
	        $fvFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1) 
	        $SfSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName,$fldArray[$lint]) 
	        $findFolderResults = $service.FindFolders($tfTargetFolder.Id,$SfSearchFilter,$fvFolderView) 
	        if ($findFolderResults.TotalCount -gt 0){ 
	            foreach($folder in $findFolderResults.Folders){ 
	                $tfTargetFolder = $folder                
	            } 
	        } 
	        else{ 
	            Write-host ("Error Folder Not Found check path and try again")  
	            $tfTargetFolder = $null  
	            break  
	        }     
	    }  
		if($tfTargetFolder -ne $null){
			return [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$tfTargetFolder.Id)
		}
		else{
			throw ("Folder Not found")
		}
	}
}

function Export-Contact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$true)] [string]$FileName
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid) 
		if($service.URL){
			$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
			$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
			$ParentFolderIds = [Activator]::CreateInstance($type)
			$ParentFolderIds.Add($Contacts.Id)
			$Error.Clear();
			$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
			if($Error.Count -eq 0){
				if ($ncCol.Count -eq 0) {
					Write-Host -ForegroundColor Yellow ("No Contact Found")		
				}
				else{
					foreach($Result in $ncCol){
						if($Result.Contact -eq $null){
							Write-Output $Result
						}
						else{
							$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $EmailAddress
							$ncCola = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
							if ($ncCola.Count -eq 0) {  
								Write-Host -ForegroundColor Yellow ("No Contact Found")			
							}
							else
							{
								Write-Host ("Number of matching Contacts Found " + $ncCol.Count)
								foreach($aResult in $ncCola){
									$psPropset= new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)    
   									$psPropset.Add([Microsoft.Exchange.WebServices.Data.ItemSchema]::MimeContent); 
									$Contact = [Microsoft.Exchange.WebServices.Data.Contact]::Bind($service,$aResult[0].Mailbox.Id,$psPropset)
									$FileName = Make-UniqueFileName -FileName $FileName
									[System.IO.File]::WriteAllBytes($FileName,$Contact.MimeContent.Content) 
            						write-host ("Exported " + $FileName)  
								}	
							}
						}
					}
				}
			}
		}
	}
}
function Export-GALContact 
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [switch]$IncludePhoto,
		[Parameter(Position=4, Mandatory=$true)] [string]$FileName
    )  
 	Begin
	{
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$Error.Clear();
		$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
		if($Error.Count -eq 0){
			foreach($Result in $ncCol){				
				if($ncCol.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()){
					Set-content -path $filename "BEGIN:VCARD" 
					add-content -path $filename "VERSION:2.1"
					$givenName = ""
					if($ncCol.Contact.GivenName -ne $null){
						$givenName = $ncCol.Contact.GivenName
					}
					$surname = ""
					if($ncCol.Contact.Surname -ne $null){
						$surname = $ncCol.Contact.Surname
					}
					add-content -path $filename ("N:" + $surname + ";" + $givenName)
					add-content -path $filename ("FN:" + $ncCol.Contact.DisplayName)
					$Department = "";
					if($ncCol.Contact.Department -ne $null){
						$Department = $ncCol.Contact.Department
					}
				
					$CompanyName = "";
					if($ncCol.Contact.CompanyName -ne $null){
						$CompanyName = $ncCol.Contact.CompanyName
					}
					add-content -path $filename ("ORG:" + $CompanyName + ";" + $Department)	
					if($ncCol.Contact.JobTitle -ne $null){
						add-content -path $filename ("TITLE:" + $ncCol.Contact.JobTitle)
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone] -ne $null){
						add-content -path $filename ("TEL;CELL;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::MobilePhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone] -ne $null){
						add-content -path $filename ("TEL;HOME;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::HomePhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone] -ne $null){
						add-content -path $filename ("TEL;WORK;VOICE:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessPhone])		
					}
					if($ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessFax] -ne $null){
						add-content -path $filename ("TEL;WORK;FAX:" + $ncCol.Contact.PhoneNumbers[[Microsoft.Exchange.WebServices.Data.PhoneNumberKey]::BusinessFax])
					}
					if($ncCol.Contact.BusinessHomePage -ne $null){
						add-content -path $filename ("URL;WORK:" + $ncCol.Contact.BusinessHomePage)
					}
					if($ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business] -ne $null){
						$Country = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].CountryOrRegion.Replace("`n","")
						$City = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].City.Replace("`n","")
						$Street = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].Street.Replace("`n","")
						$State = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].State.Replace("`n","")
						$PCode = $ncCol.Contact.PhysicalAddresses[[Microsoft.Exchange.WebServices.Data.PhysicalAddressKey]::Business].PostalCode.Replace("`n","")
						$addr = "ADR;WORK;PREF:;" + $Country + ";" + $Street + ";" + $City + ";" + $State + ";" + $PCode + ";" + $Country
						add-content -path $filename $addr
					}
					if($ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] -ne $null){
						add-content -path $filename ("X-MS-IMADDRESS:" + $ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1])
					}
					add-content -path $filename ("EMAIL;PREF;INTERNET:" + $ncCol.Mailbox.Address)
					
					
					if($IncludePhoto){
						$PhotoURL = AutoDiscoverPhotoURL -EmailAddress $MailboxName  -Credentials $Credentials
						$PhotoSize = "HR120x120" 
						$PhotoURL= $PhotoURL + "/GetUserPhoto?email="  + $ncCol.Mailbox.Address + "&size=" + $PhotoSize;
						$wbClient = new-object System.Net.WebClient
						$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
						$wbClient.Credentials = $creds
						$photoBytes = $wbClient.DownloadData($PhotoURL);
						add-content -path $filename "PHOTO;ENCODING=BASE64;TYPE=JPEG:"
						$ImageString = [System.Convert]::ToBase64String($photoBytes,[System.Base64FormattingOptions]::InsertLineBreaks)
						add-content -path $filename $ImageString
						add-content -path $filename "`r`n"	
					}
					add-content -path $filename "END:VCARD"	
					Write-Host ("Contact exported to " + $FileName)			
				}						
			}
		}
	}
}

function AutoDiscoverPhotoURL{
       param (
              $EmailAddress="$( throw 'Email is a mandatory Parameter' )",
              $Credentials="$( throw 'Credentials is a mandatory Parameter' )"
              )
       process{
              $version= [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
              $adService= New-Object Microsoft.Exchange.WebServices.Autodiscover.AutodiscoverService($version);
			  $creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
              $adService.Credentials = $creds
              $adService.EnableScpLookup=$false;
              $adService.RedirectionUrlValidationCallback= {$true}
              $adService.PreAuthenticate=$true;
              $UserSettings= new-object Microsoft.Exchange.WebServices.Autodiscover.UserSettingName[] 1
              $UserSettings[0] = [Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::ExternalPhotosUrl
              $adResponse=$adService.GetUserSettings($EmailAddress, $UserSettings)
              $PhotoURI= $adResponse.Settings[[Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::ExternalPhotosUrl]
              return $PhotoURI.ToString()
       }
}

function Copy-Contacts.GalToMailbox
{
   [CmdletBinding()] 
    param( 
    	[Parameter(Position=0, Mandatory=$true)] [string]$MailboxName,
		[Parameter(Position=1, Mandatory=$true)] [string]$EmailAddress,
		[Parameter(Position=2, Mandatory=$true)] [PSCredential]$Credentials,
		[Parameter(Position=3, Mandatory=$false)] [string]$Folder,
		[Parameter(Position=4, Mandatory=$false)] [switch]$IncludePhoto
    )  
 	Begin
	{
		#Connect
		$service = Connect-Exchange -MailboxName $MailboxName -Credential $Credentials
		$folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$MailboxName)   
		if($Folder){
			$Contacts = Get-ContactFolder -service $service -FolderPath $Folder -SmptAddress $MailboxName
		}
		else{
			$Contacts = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
		}
		$Error.Clear();
		$ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true);
		if($Error.Count -eq 0){
			foreach($Result in $ncCol){				
				if($ncCol.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()){					
					$type = ("System.Collections.Generic.List"+'`'+"1") -as "Type"
					$type = $type.MakeGenericType("Microsoft.Exchange.WebServices.Data.FolderId" -as "Type")
					$ParentFolderIds = [Activator]::CreateInstance($type)
					$ParentFolderIds.Add($Contacts.Id)
					$Error.Clear();
					$ncCola = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryThenContacts,$true);
					$createContactOkay = $false
					if($Error.Count -eq 0){
						if ($ncCola.Count -eq 0) {							
						    $createContactOkay = $true;	
						}
						else{
							foreach($aResult in $ncCola){
								if($aResult.Contact -eq $null){
									Write-host "Contact already exists " + $aResult.Contact.DisplayName
									throw ("Contact already exists")
								}
								else{
									$UserDn = Get-UserDN -Credentials $Credentials -EmailAddress $EmailAddress
									$ncColb = $service.ResolveName($UserDn,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::ContactsOnly,$true);
									if ($ncColb.Count -eq 0) {  
										$createContactOkay = $true;		
									}
									else
									{
										Write-Host -ForegroundColor  Red ("Number of existing Contacts Found " + $ncColb.Count)
										foreach($Result in $ncColb){
											Write-Host -ForegroundColor  Red ($ncColb.Mailbox.Name)
										}
										throw ("Contact already exists")
									}
								}
							}
						}
						if($createContactOkay){
							#check for SipAddress
							$IMAddress = ""
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1] -ne $null){
								$email1 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address
								if($email1.tolower().contains("sip:")){
									$IMAddress = $email1
								}
							}
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] -ne $null){
								$email2 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2].Address
								if($email2.tolower().contains("sip:")){
									$IMAddress = $email2
									$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] = $null
								}
							}
							if($ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] -ne $null){
								$email3 = $ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3].Address
								if($email3.tolower().contains("sip:")){
									$IMAddress = $email3
									$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] = $null
								}
							}
							if($IMAddress -ne ""){
								$ncCol.Contact.ImAddresses[[Microsoft.Exchange.WebServices.Data.ImAddressKey]::ImAddress1] = $IMAddress
							}	
    						$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress2] = $null
							$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress3] = $null
							$ncCol.Contact.EmailAddresses[[Microsoft.Exchange.WebServices.Data.EmailAddressKey]::EmailAddress1].Address = $ncCol.Mailbox.Address.ToLower()
							$ncCol.Contact.FileAs = $ncCol.Contact.DisplayName
							if($IncludePhoto){					
								$PhotoURL = AutoDiscoverPhotoURL -EmailAddress $MailboxName  -Credentials $Credentials
								$PhotoSize = "HR120x120" 
								$PhotoURL= $PhotoURL + "/GetUserPhoto?email="  + $ncCol.Mailbox.Address + "&size=" + $PhotoSize;
								$wbClient = new-object System.Net.WebClient
								$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
								$wbClient.Credentials = $creds
								$photoBytes = $wbClient.DownloadData($PhotoURL);
								$fileAttach = $ncCol.Contact.Attachments.AddFileAttachment("contactphoto.jpg",$photoBytes)
								$fileAttach.IsContactPhoto = $true
							}
							$ncCol.Contact.Save($Contacts.Id);
							Write-Host ("Contact copied")
						}
					}
				}
			}
		}
	}
}

function Get-UserDN{
	param (
			[Parameter(Position=0, Mandatory=$true)] [string]$EmailAddress,
			[Parameter(Position=1, Mandatory=$true)] [PSCredential]$Credentials
		  )
	process{
		$ExchangeVersion= [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
		$adService = New-Object Microsoft.Exchange.WebServices.AutoDiscover.AutodiscoverService($ExchangeVersion);
		$creds = New-Object System.Net.NetworkCredential($Credentials.UserName.ToString(),$Credentials.GetNetworkCredential().password.ToString()) 
		$adService.Credentials = $creds
		$adService.EnableScpLookup = $false;
		$adService.RedirectionUrlValidationCallback = {$true}
		$UserSettings = new-object Microsoft.Exchange.WebServices.Autodiscover.UserSettingName[] 1
		$UserSettings[0] = [Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::UserDN
		$adResponse = $adService.GetUserSettings($EmailAddress , $UserSettings);
		return $adResponse.Settings[[Microsoft.Exchange.WebServices.Autodiscover.UserSettingName]::UserDN]
	}
}