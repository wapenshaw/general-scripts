<#
.SYNOPSIS
  DEPRECATED — replaced by the modular profile in modules/.
.DESCRIPTION
  This file is kept for backward compatibility. The modular PowerShell profile
  now lives in powershell/profile/modules/ and is deployed by Install-Profile.ps1.
  The generated $PROFILE loader sources modules in order instead of this file.
  You can safely delete your installed copy at ~/.config/powershell/user_profile.ps1.
#>
Write-Verbose "User-Profile.ps1 is deprecated. Profile modules are now in modules/."
