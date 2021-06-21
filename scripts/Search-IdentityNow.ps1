function Search-IdentityNow {
    <#
.SYNOPSIS
    Search IdentityNow Access Profiles, Account Activities, Accounts, Aggregations, Entitlements, Events, Identities, Roles.

.DESCRIPTION
    Gets Access Profiles, Account Activities, Accounts, Aggregations, Entitlements, Events, Identities, Roles based on v3 search query

.PARAMETER query
    (required) Search Query. 

.PARAMETER limit
    (optional) Search Page Result Size

.PARAMETER indice
    (required) v3 Search Indice to search. 
    valid indices are "accessprofiles", "accountactivities", "accounts", "aggregations", "entitlements", "events", "identities", "roles"

.PARAMETER nested
    (optional) defaults to True 
    Indicates if nested objects from returned search results should be included

.EXAMPLE
    Search-IdentityNow -query "source.name:'Active Directory'" -indice "accessprofiles" -nested $false

.EXAMPLE
    Search-IdentityNow -query "source.id:2c918083670df373016835e063ff6b5b" -indice "entitlements" -nested $false

.EXAMPLE
    Search-IdentityNow -query "@accounts.entitlementAttributes.'App_Group_*'" -indice "accounts" -nested $false

.LINK
    http://darrenjrobinson.com/sailpoint-identitynow

#>

    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$query,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [int]$limit = 2500,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string][ValidateSet("accessprofiles", "accountactivities", "accounts", "aggregations", "entitlements", "events", "identities", "roles")]$indice,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [boolean]$nested = $true 
    )

    if ($limit -gt 10000) {
        Write-Error "Maximum search limit provided by the API is 10,000 results? Reduce your search limit parameter."
        break  
    }

    $v3Token = Get-IdentityNowAuth -return V3JWT

    if ($v3Token.access_token) {
        try {                         
            $results = $null 
            $sourceObjects = @() 
            
            switch ($indice) {
                "accessprofiles" { $body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"name`"]}"}
                "accountactivities" { $body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"id`"]}" }
                "accounts" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"name`"]}"}
                "aggregations" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested)}"}
                "entitlements" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"source.name`"]}"}
                "events" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"-created`"]}"}
                "identities" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"displayName`"]}"}
                "roles" {$body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"name`"]}"}
                Default { $body = "{`"query`":{`"query`":`"$($query)`"},`"indices`":[`"$($indice)`"],`"includeNested`":$($nested),`"sort`":[`"name`"]}" }
            } 
            
            $results = Invoke-RestMethod -Method Post `
                -Uri "https://$($IdentityNowConfiguration.orgName).api.identitynow.com/v3/search?offset=0&limit=$($limit)&count=false" `
                -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)"; 'Content-Type' = 'application/json' } `
                -Body $body                       

            if ($results.count -gt 0) {
                $sourceObjects += $results
            } else {
                return $sourceObjects
                break
            }
            if ($results.count -gt 0 -and $results.count -lt $limit ) {
                # don't continue as we have all the results
                return $sourceObjects
                break 
            }
            else {
                $offset = 0
                do { 
                    if ($results.Count -lt $limit) {
                        # Get Next Page
                        [int]$offset = $offset + $limit 
                        $results = Invoke-RestMethod -Method Post `
                            -Uri "https://$($IdentityNowConfiguration.orgName).api.identitynow.com/v3/search?offset=$($offset)&limit=$($limit)&count=false" `
                            -Headers @{Authorization = "$($v3Token.token_type) $($v3Token.access_token)" ; 'Content-Type' = 'application/json' }  `
                            -Body $body

                        if ($results) {
                            $sourceObjects += $results
                        }
                    }
                } until ($results.Count -ge $limit)
                return $sourceObjects
            }
        }
        catch {
            Write-Error "Bad Query or more than 10,000 results? Check your query."
            Write-Error $($_) 
        }
    }
    else {
        Write-Error "Authentication Failed. Check your AdminCredential and v3 API ClientID and ClientSecret."
        Write-Error $($_)
        return $v3Token
    } 
}


# SIG # Begin signature block
# MIINSwYJKoZIhvcNAQcCoIINPDCCDTgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYOWNMAYIMzlTq4EazFrSqgwJ
# W8SgggqNMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0B
# AQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVk
# IElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# Q29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
# +NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPApfmJ
# 1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0
# sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6s
# cKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4Tz
# rGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg
# 0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB/wIB
# ADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYBBQUH
# AQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYI
# KwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaG
# NGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RD
# QS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYE
# FFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1dHC06
# GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/cY5j
# DhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6cSgC
# PC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwlCEIy
# sjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4Gb
# T8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIFVTCC
# BD2gAwIBAgIQDOzRdXezgbkTF+1Qo8ZgrzANBgkqhkiG9w0BAQsFADByMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBMB4XDTIwMDYxNDAwMDAwMFoXDTIzMDYxOTEyMDAwMFowgZEx
# CzAJBgNVBAYTAkFVMRgwFgYDVQQIEw9OZXcgU291dGggV2FsZXMxFDASBgNVBAcT
# C0NoZXJyeWJyb29rMRowGAYDVQQKExFEYXJyZW4gSiBSb2JpbnNvbjEaMBgGA1UE
# CxMRRGFycmVuIEogUm9iaW5zb24xGjAYBgNVBAMTEURhcnJlbiBKIFJvYmluc29u
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwj7PLmjkknFA0MIbRPwc
# T1JwU/xUZ6UFMy6AUyltGEigMVGxFEXoVybjQXwI9hhpzDh2gdxL3W8V5dTXyzqN
# 8LUXa6NODjIzh+egJf/fkXOgzWOPD5fToL7mm4JWofuaAwv2DmI2UtgvQGwRhkUx
# Y3hh0+MNDSyz28cqExf8H6mTTcuafgu/Nt4A0ddjr1hYBHU4g51ZJ96YcRsvMZSu
# 8qycBUNEp8/EZJxBUmqCp7mKi72jojkhu+6ujOPi2xgG8IWE6GqlmuMVhRSUvF7F
# 9PreiwPtGim92RG9Rsn8kg1tkxX/1dUYbjOIgXOmE1FAo/QU6nKVioJMNpNsVEBz
# /QIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1Dlgw
# HQYDVR0OBBYEFOh6QLkkiXXHi1nqeGozeiSEHADoMA4GA1UdDwEB/wQEAwIHgDAT
# BgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0
# cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYD
# VR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggr
# BgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJo
# dHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElE
# Q29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOC
# AQEANWoHDjN7Hg9QrOaZx0V8MK4c4nkYBeFDCYAyP/SqwYeAtKPA7F72mvmJV6E3
# YZnilv8b+YvZpFTZrw98GtwCnuQjcIj3OZMfepQuwV1n3S6GO3o30xpKGu6h0d4L
# rJkIbmVvi3RZr7U8ruHqnI4TgbYaCWKdwfLb/CUffaUsRX7BOguFRnYShwJmZAzI
# mgBx2r2vWcZePlKH/k7kupUAWSY8PF8O+lvdwzVPSVDW+PoTqfI4q9au/0U77UN0
# Fq/ohMyQ/CUX731xeC6Rb5TjlmDhdthFP3Iho1FX0GIu55Py5x84qW+Ou+OytQcA
# FZx22DA8dAUbS3P7OIPamcU68TGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0ECEAzs0XV3s4G5ExftUKPGYK8wCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFIezdNK4m3hB
# IonEk/YKfIWMQEMUMA0GCSqGSIb3DQEBAQUABIIBAKdt4pCir4TNmXPTedSnRvpH
# hV7WLTeSPvqaN636Bs8GBzggbPjyY+66LYuDcaaMpwL5MlayFi7LntCN6ZFMDT7f
# VUF3Ql9sfNy8Qi4xy/MLbyvbzL5ua5Qk9T11hUAng7IRnOxdZqoT8sYIhaPaFA0X
# fLT2LzfI1z1H+gjRzMUduiXMwxcvqtPGuvQriiCnYXXE+oDslPx6gDlS15ve/Wvh
# +YDpopKdzSBSG2AOWSjRAuuPPYzBA8XVixUpDkR7thEWtbSyBpIacU4tmsHED2uM
# M9Aqs3EXjrNchVdbyyp2ABaCb41TGG/sgJ8jGF8Iprj1ZeyG7g1AFSa/BjZt4fQ=
# SIG # End signature block
