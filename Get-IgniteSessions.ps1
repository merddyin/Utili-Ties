function Get-IgniteSessions {
<#
	.SYNOPSIS
		Mass and individual download of both, or either, MS Ignite 2019 videos and slide decks

	.DESCRIPTION
		Utility to download files related to MS Ignite 2019 sessions, including MP4 videos and associated PowerPoint decks to
		the local file system. This is an efficiency augmentation of the various download scripts floating around.

		Note: In this version, filtering parameters are mutually exclusive, so only one may be used per query. While I need to 
		fix this, it's just not a priority at the moment.
	
	.PARAMETER SessionCode
		Accepts one or more session ID codes, both via named parameter, or from the pipeline.

		Note: Some sessions do not have proper session IDs

	.PARAMETER SessionTitle
		Used to specify all or just a portion of the session name as the search method to find sessions to download, as well as 
		accepting pipeline input.

	.PARAMETER Topic
		Used to specify all or just a portion of the session topic as the search method to find sessions to download, as well as 
		accepting pipeline input.

	.PARAMETER Level
		Used to specify the session level in numerical format (100, 200, 300, or 400) as the search method to find sessions to 
		download, as well as accepting pipeline input.

	.PARAMETER Products
		Used to specify all or just a portion of the product name as the search method to find sessions to download, as well as 
		accepting pipeline input.

	.PARAMETER SpeakerNames
		Used to specify all, or just a portion, of the speaker name as the search method to find sessions to download, as well 
		as accepting pipeline input.

	.PARAMETER SpeakerCompanies
		Used to specify all, or just a portion, of the speaker company name as the search method to find sessions to download, 
		as well as accepting pipeline input.

	.PARAMETER DownloadDir
		Used to specify the full path of a local folder to download session files to. If this parameter is not specified, the
		function will create an 'Ignite2019' folder in the Documents location of the account running the script.
		
	.PARAMETER VideoOnly
		By default, both Videos and their associated PowerPoint decks, if available, are downloaded. By including this switch,
		only the Videos will be downloaded.

	.PARAMETER SlidesOnly
		By default, both Videos and their associated PowerPoint decks, if available, are downloaded. By including this switch,
		only the PowerPoint deck will be downloaded.

	.EXAMPLE
		PS C:\> "THR2120","THR2123","THR2130" | Get-IgniteSessions -DownloadDir "C:\MyStuff\Ignite"

		Downloads both the videos and the decks for the three sessions with the specified session IDs to C:\MyStuff\Ignite.

	.EXAMPLE
		PS C:\> Import-Csv C:\MyStuff\IgniteProducts.csv | Get-IgniteSessions

		Imports a CSV with a single column named 'Products', and downloads any identified sessions to the default location of
		'C:\Users\<UserName>\Documents\Ignite2019' where '<UserName>' is the account name of the person running the function.

	.NOTES
		This function has been tested within Windows PowerShell 5.1 and PowerShell Core 7 Preview 5 on Windows 10 1903. When 
		running this function within PowerShell Core, files are downloaded in parallel using the new 'foreach -Parallel' 
		functionality. This 'foreach' is NOT the same as the 'ForEach-Object' or 'Foreach($item in $items)' methods, though
		it can be accessed via the '%' alias. 
#>
	[CmdletBinding(DefaultParameterSetName="All")]
	param (
		[Parameter(Position=0,ParameterSetName="Code",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[string[]]$SessionCode,
		[Parameter(ParameterSetName="Title",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[SupportsWildcards()]
		[string]$SessionTitle,
		[Parameter(ParameterSetName="Topic",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[SupportsWildcards()]
		[string[]]$Topic,
		[Parameter(ParameterSetName="Level",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[ValidateSet(100,200,300,400)]
		[int[]]$Level,
		[Parameter(ParameterSetName="Product",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[SupportsWildcards()]
		[string[]]$Products,
		[Parameter(ParameterSetName="Name",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[SupportsWildcards()]
		[string[]]$SpeakerNames,
		[Parameter(ParameterSetName="Company",ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[SupportsWildcards()]
		[string[]]$SpeakerCompanies,
		[string]$DownloadDir=(Join-Path -Path ($ENV:USERPROFILE) -ChildPath "Documents"),
		[switch]$VideoOnly,
		[switch]$SlidesOnly
	)

	$DefaultDir = (Join-Path -Path ($ENV:USERPROFILE) -ChildPath "Documents")
	
	if($DownloadDir -like $DefaultDir){
		$DestPath = (New-Item -Path $DownloadDir -Name "Ignite2019" -ItemType Directory).FullName
	}else{
		if(!(Test-Path $DownloadDir -PathType Container)){
			Throw "Specified path ($DownloadDir) does not represent a valid directory"
		}else{
			$DestPath = $DownloadDir
		}
	}
	
	try {
		$Sessions = (Invoke-RestMethod 'https://api-myignite.techcommunity.microsoft.com/api/session/all')
	}
	catch {
		Throw "Failed to connect to URL to retrieve sessions. Check your internet connection."
	}
	
	if($Sessions){
		Write-Host "Retrieved $($Sessions.Count) total sessions"
	}else{
		Throw "No sessions retrieved"
	}
	
	$FiltSessions = @()

	switch ($pscmdlet.ParameterSetName){
		"Code" {
			foreach($item in $SessionCode){
				$FiltSessions += $Sessions | Where-Object{$_.sessionCode -like $item}
			}
		}
		"Title" {			
			foreach($item in $SessionTitle){
				$FiltSessions += $Sessions | Where-Object{$_.title -match $item}
			}
		}
		"Topic" {
			foreach($item in $Topic){
				$FiltSessions += $Sessions | Where-Object{$_.topic -match $item}
			}
		}
		"Level" {
			foreach($item in $Level){
				$FiltSessions += $Sessions | Where-Object{$_.level -match $item}
			}
		}
		"Product" {
			foreach($item in $Products){
				$FiltSessions += $Sessions | Where-Object{$_.products -match $item}
			}
		}
		"Name" {
			foreach($item in $SpeakerNames){
				$FiltSessions += $Sessions | Where-Object{$_.speakerNames -match $item}
			}
		}
		"Company" {
			foreach($item in $SpeakerCompanies){
				$FiltSessions += $Sessions | Where-Object{$_.speakerCompanies -match $item}
			}
		}
	}
	
	if($FiltSessions){
		if($PSVersionTable.PSEdition -like "Core"){
			Write-Host "Downloading $($FiltSessions.count) sessions to $DestPath with parallel processing..." -Foreground Yellow
			$FiltSessions | foreach -Parallel {
				if($_.sessionCode){
					$pre = $_.sessionCode
				}else{
					$pre = "UKN$(Get-Random -Min 1000 -Max 2000)"
				}
				
				$Downloads = @()
				
				$DObj = [PSCustomObject]@{
					DType = "Video"
					URL = $_.downloadVideoLink
					DPath = Join-Path $using:DestPath "$($pre).mp4"
				}
				$Downloads += $DObj

				$DObj = [PSCustomObject]@{
					DType = "Slide"
					URL = $_.slideDeck
					DPath = Join-Path $using:DestPath "$($pre).pptx"
				}
				$Downloads += $DObj
				
				if($VideoOnly){
					$FiltDownloads = $Downloads | Where-Object{$_.DType -like "Video"}
				}elseif($SlidesOnly){
					$FiltDownloads = $Downloads | Where-Object{$_.DType -like "Slide"}
				}else{
					$FiltDownloads = $Downloads
				}
				
				
				foreach($download in $FiltDownloads){
					if(Test-Path $download.DPath){
						Invoke-WebRequest $($download.URL) -OutFile $download.DPath -MaximumRetryCount 3 -Resume
					}else{
						Invoke-WebRequest $($download.URL) -OutFile $download.DPath -MaximumRetryCount 3 
					}
				}
			}
		}else{
			Write-Host "Downloading $($FiltSessions.count) sessions to $DestPath..." -Foreground Yellow
			$FiltSessions | foreach {
				if($_.sessionCode){
					$pre = $_.sessionCode
				}else{
					$pre = "UKN$(Get-Random -Min 1000 -Max 2000)"
				}
				
				$Downloads = @()
				
				$DObj = [PSCustomObject]@{
					DType = "Video"
					URL = $_.downloadVideoLink
					DPath = Join-Path $DestPath "$($pre).mp4"
				}
				$Downloads += $DObj

				$DObj = [PSCustomObject]@{
					DType = "Slide"
					URL = $_.slideDeck
					DPath = Join-Path $DestPath "$($pre).mp4"
				}
				$Downloads += $DObj
				
				if($VideoOnly){
					$FiltDownloads = $Downloads | Where-Object{$_.DType -like "Video"}
				}elseif($SlidesOnly){
					$FiltDownloads = $Downloads | Where-Object{$_.DType -like "Slide"}
				}else{
					$FiltDownloads = $Downloads
				}
				
				
				foreach($download in $FiltDownloads){
					if(Test-Path $download.DPath){
						Invoke-WebRequest $($download.URL) -OutFile $download.DPath -Resume
					}else{
						Invoke-WebRequest $($download.URL) -OutFile $download.DPath
					}
				}
			}
		}
	}else{
		Write-Warning "No sessions were found using the specified search values. For values such as Title, "
	}
}
