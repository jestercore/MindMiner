<#
MindMiner  Copyright (C) 2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2v3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z330" } # work only on one gpu
		# [AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescrypt" } is r8g
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr8g" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "yescryptr16" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "yescryptr24" }
		[AlgoInfoEx]@{ Enabled = $([Config]::ActiveTypes -notcontains [eMinerType]::CPU); Algorithm = "yescryptr32" }
)}

if (!$Cfg.Enabled) { return }
if ([Config]::CudaVersion -lt [version]::new(10, 0)) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$N = Get-CCMinerStatsAvg $Algo $_
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				if ($_.Algorithm -match "yescryptr8g") { $_.Algorithm = "yescrypt" }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ccminer"
					URI = "https://github.com/Minerx117/ccmineryescryptr8g/releases/download/v4/ccmineryescryptrv4.zip"
					Path = "$Name\ccminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -o stratum+tcp://$($Pool.Hosts[0]):$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password) -R $($Config.CheckTimeout) -q -b 4068 $N $extrargs"
					Port = 4068
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}