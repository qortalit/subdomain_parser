
$ScriptDir = Split-Path -Parent $PSCommandPath


$DomainsFile = Join-Path $ScriptDir 'domains.txt'


$ResultsDir = Join-Path $ScriptDir 'results'
if (!(Test-Path $ResultsDir)) {
    New-Item -Path $ResultsDir -ItemType Directory | Out-Null
}


$ResultsFile = Join-Path $ResultsDir 'Name.csv'


$subdomains = Get-Content -Path $DomainsFile


$results = @()

foreach ($sub in $subdomains) {

    $result = [PSCustomObject]@{
        Subdomain    = $sub
        HTTP_Status  = $null
        HTTPS_Status = $null
        Resolved_IP  = $null
    }

    
    try {
        $dns = Resolve-DnsName -Name $sub -ErrorAction Stop | Where-Object Type -eq 'A'
        $result.Resolved_IP = $dns.IPAddress -join ', '
    } catch {
        $result.Resolved_IP = "Not allowed"
    }

    
    try {
        $response = Invoke-WebRequest -Uri "http://$sub" -TimeoutSec 3 -ErrorAction Stop
        $result.HTTP_Status = $response.StatusCode
    } catch {
        $result.HTTP_Status = "Error: $($_.Exception.Message)"
    }

    
    try {
        $response = Invoke-WebRequest -Uri "https://$sub" -TimeoutSec 3 -ErrorAction Stop
        $result.HTTPS_Status = $response.StatusCode
    } catch {
        $result.HTTPS_Status = "Error: $($_.Exception.Message)"
    }

    $results += $result

    
    if ($result.HTTP_Status -match "^\d+$" -or $result.HTTPS_Status -match "^\d+$") {
        Write-Host "[+] $sub" -ForegroundColor Green -NoNewline
        Write-Host " | DNS: $($result.Resolved_IP)" -ForegroundColor Cyan
        if ($result.HTTP_Status -match "^\d+$") { Write-Host "  HTTP: $($result.HTTP_Status)" -ForegroundColor Blue }
        if ($result.HTTPS_Status -match "^\d+$") { Write-Host "  HTTPS: $($result.HTTPS_Status)" -ForegroundColor DarkBlue }
    }
    else {
        Write-Host "[-] $sub - doesn't answer" -ForegroundColor Red
    }

    Start-Sleep -Milliseconds 200
}

$results | Export-Csv -Path $ResultsFile -NoTypeInformation -Encoding UTF8

Write-Host "`nFine! Results saved in $ResultsFile" -ForegroundColor Magenta