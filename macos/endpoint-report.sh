#!/bin/bash
# Read-only endpoint inventory for modern macOS. Uses only macOS-supplied tools.
# Normal: bash endpoint-report.sh > endpoint-report.txt
# Extra access: sudo bash endpoint-report.sh > endpoint-report.txt
# No installations, changes to security settings, or uploads. Reports to stdout.
# Only selected configuration fields are printed; no raw profiles or agent logs.

set -u
set -o pipefail
export LC_ALL=C

REPORT_PROBE_BIGFIX=0
while [[ $# -gt 0 ]]; do
case "$1" in
--probe-bigfix)
    REPORT_PROBE_BIGFIX=1
    shift
    ;;
--help|-h)
    /bin/cat <<'HELP'
Usage: bash endpoint-report.sh [--probe-bigfix] > endpoint-report.txt
       sudo bash endpoint-report.sh [--probe-bigfix] > endpoint-report.txt

Reports OS name/version/build, kernel, architecture, boot time and uptime,
installed security/management tools, versions, running processes,
system extensions, MDM enrollment, management server hostnames, relevant
configuration profiles, agent permissions, and macOS protection settings.
BigFix checks include its service state, lock setting, relay selection,
and timestamps for successful registration, report uploads and synchronization.

--probe-bigfix also tests one TCP connection to the last registered relay,
or the configured primary relay if no registration event is available.
It uses a 3-second connection timeout and sends no application data.

sudo adds access to protected files/logs and CrowdStrike's local statistics.
macOS privacy controls can still restrict access, even with sudo.
The script only reads configuration and writes its report to stdout.
Review the report before sharing; it includes your organization's server names.
HELP
    exit 0
    ;;
*)
    printf 'Unknown argument. Use --help for instructions.\n' >&2
    exit 2
    ;;
esac
done
if [[ "$(/usr/bin/uname -s)" != Darwin ]]; then
    printf 'This script requires macOS.\n' >&2
    exit 1
fi

REPORT_PATTERN='crowdstrike|falcon|fireeye|trellix|bigfix|besagent|besclient|bf-scanner|forescout|secureconnector|jamf|jcdaemon|self service|globalprotect|pangp|company portal|intune|defender|mdatp|symantec|sophos|sentinelone|sentineld|carbonblack|carbon black|cylance|cisco secure|cisco anyconnect|rustdesk|triggerclient'

section() { printf '\n=== %s ===\n' "$1"; }

redact() {
    /usr/bin/sed -E \
        -e 's@/Users/[^/[:space:]]+@/Users/[redacted]@g' \
        -e 's/[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}/[UUID redacted]/g' \
        -e 's/[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}/[email redacted]/g'
}

check() {
    local REPORT_LABEL="$1" REPORT_VALUE
    shift
    if REPORT_VALUE=$("$@" 2>/dev/null) && [[ -n "$REPORT_VALUE" ]]; then
        printf '%s: %s\n' "$REPORT_LABEL" "$REPORT_VALUE"
    else
        printf '%s: unavailable with current permissions\n' "$REPORT_LABEL"
    fi
}

app() {
    local REPORT_LABEL="$1" REPORT_APP="$2" REPORT_VERSION REPORT_BUILD
    [[ -d "$REPORT_APP" ]] || return 0
    REPORT_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$REPORT_APP/Contents/Info.plist" 2>/dev/null) || REPORT_VERSION='unavailable'
    REPORT_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$REPORT_APP/Contents/Info.plist" 2>/dev/null) || REPORT_BUILD=''
    printf '%s | version %s' "$REPORT_LABEL" "$REPORT_VERSION"
    if [[ -n "$REPORT_BUILD" && "$REPORT_BUILD" != "$REPORT_VERSION" ]]; then
        printf ' | build %s' "$REPORT_BUILD"
    fi
    printf ' | %s\n' "$REPORT_APP"
}

printf 'macOS endpoint report\n'
printf 'Collected: %s\n' "$(/bin/date -u '+%Y-%m-%d %H:%M:%S UTC')"
if [[ $EUID -eq 0 ]]; then
    printf 'Access: administrator (sudo/root)\n'
else
    printf 'Access: standard user; use sudo for protected settings\n'
fi
printf 'Running processes/extensions indicate local activity, not verified cloud reporting.\n'
section 'Operating system information'
check 'OS name' /usr/bin/sw_vers -productName
check 'macOS version' /usr/bin/sw_vers -productVersion
check 'macOS build' /usr/bin/sw_vers -buildVersion
check 'Kernel' /usr/bin/uname -s
check 'Kernel release' /usr/bin/uname -r
check 'Architecture' /usr/bin/uname -m
REPORT_BOOT_SECONDS=$(/usr/sbin/sysctl -n kern.boottime 2>/dev/null | /usr/bin/sed -nE 's/^\{ sec = ([0-9]+),.*/\1/p') || REPORT_BOOT_SECONDS=''
REPORT_NOW_SECONDS=$(/bin/date '+%s')
if [[ "$REPORT_BOOT_SECONDS" =~ ^[0-9]+$ ]] && (( REPORT_NOW_SECONDS >= REPORT_BOOT_SECONDS )); then
    check 'Last boot (UTC)' /bin/date -u -r "$REPORT_BOOT_SECONDS" '+%Y-%m-%d %H:%M:%S UTC'
    REPORT_UPTIME_SECONDS=$((REPORT_NOW_SECONDS - REPORT_BOOT_SECONDS))
    printf 'Uptime: %s days, %s hours, %s minutes\n' \
        "$((REPORT_UPTIME_SECONDS / 86400))" \
        "$((REPORT_UPTIME_SECONDS % 86400 / 3600))" \
        "$((REPORT_UPTIME_SECONDS % 3600 / 60))"
else
    printf 'Last boot and uptime: unavailable\n'
fi

section 'Known security and management applications'
app 'CrowdStrike Falcon' '/Applications/Falcon.app'
app 'FireEye / Trellix agent' '/Library/FireEye/xagt/xagt.app'
app 'FireEye Helper' '/Applications/FireEye Helper.app'
app 'BigFix agent' '/Library/BESAgent/BESAgent.app'
app 'BigFix client launcher' '/Applications/TriggerClientUI.app'
app 'ForeScout SecureConnector' '/Applications/ForeScout SecureConnector.app'
app 'Jamf management agent' '/Library/Application Support/JAMF/Jamf.app'
app 'Jamf Connect daemon' '/Library/Application Support/JamfConnect/JCDaemon.app'
app 'Jamf Connect' '/Applications/Jamf Connect.app'
app 'Jamf Self Service' '/Applications/Self Service.app'
app 'Jamf Self Service+' '/Applications/Self Service+.app'
app 'GlobalProtect VPN' '/Applications/GlobalProtect.app'
app 'Microsoft Company Portal' '/Applications/Company Portal.app'
app 'Microsoft Defender' '/Applications/Microsoft Defender.app'
printf 'Other matching applications (if present):\n'
for REPORT_APP in /Applications/*.app /Applications/*/*.app; do
    [[ -d "$REPORT_APP" ]] || continue
    if printf '%s\n' "$REPORT_APP" | /usr/bin/grep -Eiq "$REPORT_PATTERN"; then
        case "$REPORT_APP" in
            '/Applications/Falcon.app'|'/Applications/FireEye Helper.app'|'/Applications/TriggerClientUI.app'|'/Applications/ForeScout SecureConnector.app'|'/Applications/Jamf Connect.app'|'/Applications/Self Service.app'|'/Applications/Self Service+.app'|'/Applications/GlobalProtect.app'|'/Applications/Company Portal.app'|'/Applications/Microsoft Defender.app') continue ;;
        esac
        app "${REPORT_APP##*/}" "$REPORT_APP"
    fi
done

section 'Matching running processes (executable names; no command arguments)'
if ! /bin/ps -axo comm= 2>/dev/null | /usr/bin/grep -Ei "$REPORT_PATTERN" | /usr/bin/sort -u | redact; then
    printf 'No matches found, or process listing unavailable.\n'
fi

section 'System extensions (includes any unrelated extensions)'
check 'Extension listing' /usr/bin/systemextensionsctl list

section 'MDM enrollment'
if REPORT_MDM=$(/usr/bin/profiles status -type enrollment 2>/dev/null); then
    printf '%s\n' "$REPORT_MDM" | /usr/bin/awk '
        /^Enrolled via DEP:|^MDM enrollment:/ { print; next }
        /^MDM server:/ {
            sub(/^MDM server:[[:space:]]*/, "")
            sub(/^[[:alnum:]+.-]+:\/\//, "")
            sub(/^[^\/@]*@/, "")
            sub(/[\/:?#].*$/, "")
            print "MDM server hostname: " $0
        }'
else
    printf 'Enrollment status unavailable with current permissions.\n'
fi

section 'Management hosts (hostnames only; not URLs, tokens or IDs)'
/usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Foundation');
function run() {
    var rows = [];
    function readPlist(path) {
        var data = $.NSData.dataWithContentsOfFile(path);
        if (!data) return null;
        try {
            return ObjC.deepUnwrap($.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 0, Ref(), Ref()));
        } catch (e) { return null; }
    }
    function host(value) {
        if (typeof value !== 'string') return null;
        var m = value.match(/^https?:\/\/(?:[^\/@]*@)?([a-z0-9.-]+)(?=[:\/?#]|$)/i);
        return m ? m[1].toLowerCase() : null;
    }
    var jamf = readPlist('/Library/Preferences/com.jamfsoftware.jamf.plist');
    var jamfHost = jamf && host(jamf.jss_url || jamf.jssURL);
    rows.push('Jamf management host: ' + (jamfHost || 'not found or not readable'));
    var masthead = '/Library/Application Support/BigFix/BES Agent/actionsite.afxm';
    var text = $.NSString.stringWithContentsOfFileEncodingError(masthead, $.NSUTF8StringEncoding, Ref());
    var hosts = [];
    if (text) {
        var urls = ObjC.unwrap(text).match(/https?:\/\/[^\s<>"']+/g) || [];
        urls.forEach(function(url) { var h = host(url); if (h && hosts.indexOf(h) < 0) hosts.push(h); });
    }
    rows.push('BigFix masthead hosts (may include vendor infrastructure): ' + (hosts.length ? hosts.join(', ') : 'not found or not readable'));
    return rows.join('\n');
}
JXA

section 'BigFix local status and recent communication'
REPORT_BIGFIX_LABEL=$(/usr/libexec/PlistBuddy -c 'Print :Label' '/Library/LaunchDaemons/BESAgentDaemon.plist' 2>/dev/null) || REPORT_BIGFIX_LABEL='com.bigfix.BESAgent'
if [[ "$REPORT_BIGFIX_LABEL" =~ ^[A-Za-z0-9._-]+$ ]] && REPORT_BIGFIX_LAUNCH=$(/bin/launchctl print "system/$REPORT_BIGFIX_LABEL" 2>/dev/null); then
    printf '%s\n' "$REPORT_BIGFIX_LAUNCH" | /usr/bin/awk '
        !state_seen && /^[[:space:]]*state = / {
            sub(/^[[:space:]]*state = /, ""); print "Launch daemon state: " $0; state_seen=1
        }
        /^[[:space:]]*last exit code = / {
            sub(/^[[:space:]]*last exit code = /, ""); print "Last launchd exit: " $0; exit
        }'
else
    printf 'Launch daemon status: unavailable or service not loaded\n'
fi
if REPORT_BIGFIX_PROCESSES=$(/bin/ps -axo comm= 2>/dev/null); then
    if printf '%s\n' "$REPORT_BIGFIX_PROCESSES" | /usr/bin/grep -Eq '/BESAgent\.app/Contents/MacOS/BESAgent$'; then
        printf 'Agent process: running\n'
    else
        printf 'Agent process: not found\n'
    fi
    if printf '%s\n' "$REPORT_BIGFIX_PROCESSES" | /usr/bin/grep -Eq '/bf-scanner$'; then
        printf 'Inventory scanner process: running\n'
    else
        printf 'Inventory scanner process: not found (may run on a schedule)\n'
    fi
else
    printf 'Agent/scanner process status: unavailable\n'
fi

# Read a whitelist of preference fields and classify log events. Never print raw
# log lines, action commands, registration query strings or client identifiers.
REPORT_BIGFIX_DETAIL=$(/usr/bin/osascript -l JavaScript <<'BIGFIX_JXA'
ObjC.import('Foundation');
function run() {
    var prefsPath = '/Library/Preferences/com.bigfix.BESAgent.plist';
    var logDir = '/Library/Application Support/BigFix/BES Agent/__BESData/__Global/Logs';
    var fm = $.NSFileManager.defaultManager;
    var rows = [], latest = {}, now = Date.now();
    var config = null, probeTarget = null;
    function setting(obj, name) {
        var value = obj && obj[name];
        return value && typeof value === 'object' ? value.Value : value;
    }
    function endpoint(value) {
        if (typeof value !== 'string') return null;
        var m = value.match(/^https?:\/\/(?:[^\/@]*@)?(\[[0-9a-f:]+\]|[a-z0-9._-]+)(?::([0-9]+))?(?=[\/?#]|$)/i);
        if (!m) return null;
        var port = m[2] ? Number(m[2]) : /^https:/i.test(value) ? 443 : 80;
        var host = m[1].replace(/^\[|\]$/g, '');
        if (port < 1 || port > 65535 || !/^[a-z0-9]/i.test(host) && !/^[0-9a-f:]+$/i.test(host)) return null;
        return {host:host, port:port};
    }
    function describe(ep) {
        return (ep.host.indexOf(':') >= 0 ? '[' + ep.host + ']' : ep.host) + ':' + ep.port;
    }
    function remember(type, event) {
        if (event && (!latest[type] || event.time >= latest[type].time)) latest[type] = event;
    }
    function timestamp(day, match) {
        var offset = (Number(match[5].slice(1, 3)) * 60 + Number(match[5].slice(3, 5))) * (match[5][0] === '-' ? -1 : 1);
        var ms = Date.UTC(Number(day.slice(0, 4)), Number(day.slice(4, 6)) - 1, Number(day.slice(6, 8)), Number(match[2]), Number(match[3]), Number(match[4])) - offset * 60000;
        return {time:ms};
    }
    function when(event) {
        var iso = new Date(event.time).toISOString().replace('T', ' ').replace(/\.\d{3}Z$/, ' UTC');
        var minutes = Math.floor((now - event.time) / 60000);
        return iso + (minutes >= 0 ? ' (' + minutes + ' minutes ago)' : ' (timestamp is ahead of the current clock)');
    }
    try {
        var data = $.NSData.dataWithContentsOfFile(prefsPath);
        if (data) config = ObjC.deepUnwrap($.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 0, Ref(), Ref()));
    } catch (e) {}
    if (config) {
        var client = config.Settings && config.Settings.Client;
        var global = config.Options && config.Options.GlobalOptions;
        var locked = String(setting(client, '__LockState')).toLowerCase();
        rows.push('Configured action lock (__LockState): ' + (/^(1|true)$/.test(locked) ? 'locked' : /^(0|false)$/.test(locked) ? 'unlocked' : 'not set or not recognized'));
        var automatic = String(setting(client, '__RelaySelect_Automatic'));
        rows.push('Automatic relay selection: ' + (automatic === '1' ? 'enabled' : automatic === '0' ? 'disabled' : 'not set or not recognized'));
        var server = setting(global, 'ServerName');
        if (typeof server === 'string' && /^[a-z0-9][a-z0-9._-]*$/i.test(server)) rows.push('Configured server hostname: ' + server);
        probeTarget = endpoint(setting(client, '__RelayServer1'));
        if (probeTarget) rows.push('Configured primary relay: ' + describe(probeTarget));
        ['LastRegistrationServerVersion', 'LastRelayVersion', 'ReportSequenceNumber', 'LastFullReportSequenceNumber'].forEach(function(key) {
            var value = setting(global, key);
            if (/^[0-9.]+$/.test(String(value))) rows.push('Recorded ' + key + ': ' + value);
        });
        var interval = setting(client, '_BESClient_Report_MinimumInterval');
        if (/^[0-9]+$/.test(String(interval))) rows.push('Configured minimum report interval (seconds): ' + interval);
    } else rows.push('BigFix preferences: not found or not readable with current permissions');

    var files = [], scanned = 0, skipped = 0, modified = null;
    try {
        files = ObjC.deepUnwrap(fm.contentsOfDirectoryAtPathError(logDir, Ref())) || [];
        files = files.filter(function(name) { return /^\d{8}\.(log|bkg)$/.test(name); }).sort().slice(-24);
    } catch (e) {}
    files.forEach(function(name) {
        try {
            var path = logDir + '/' + name;
            var attrs = fm.attributesOfItemAtPathError(path, Ref());
            if (!attrs || Number(ObjC.unwrap(attrs.objectForKey('NSFileSize'))) > 8 * 1024 * 1024) { skipped++; return; }
            var text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, Ref());
            if (!text) { skipped++; return; }
            scanned++;
            var updated = Number(attrs.objectForKey('NSFileModificationDate').timeIntervalSince1970) * 1000;
            if (!modified || updated > modified.time) modified = {time:updated};
            var event = null, day = name.slice(0, 8);
            ObjC.unwrap(text).split(/\r?\n/).forEach(function(line) {
                var at = line.match(/^At ((\d{2}):(\d{2}):(\d{2})) ([+-]\d{4})\b/);
                if (at) { event = timestamp(day, at); return; }
                if (!event) return;
                var message = line.trim();
                if (/^(Encrypted )?Report posted successfully\.?$/i.test(message)) remember('report', event);
                else if (/^Registered with url /i.test(message)) {
                    var uri = message.match(/https?:\/\/[^\s\x27\x22<>]+/i);
                    remember('registration', {time:event.time, endpoint:uri ? endpoint(uri[0]) : null});
                } else if (/^Successful Synchronization with site /i.test(message)) remember('sync', event);
                else if (/\b(fail(?:ed|ure)?|error)\b/i.test(message) && /^(RegisterOnce|Registration|Http|HTTPConnection|ClientRegister|Report|Failed to (post|register|connect)|Relay Select Failed|PostResults)\b/i.test(message)) remember('error', event);
            });
        } catch (e) { skipped++; }
    });
    rows.push('Log scan: ' + scanned + ' readable daily/backup logs (most recent 24 files; max 8 MiB each)' + (skipped ? '; ' + skipped + ' skipped' : ''));
    if (modified) rows.push('Latest scanned log update: ' + when(modified));
    var labels = {report:'Last successful report upload', registration:'Last successful registration', sync:'Last successful site synchronization', error:'Last recognized communication error'};
    Object.keys(labels).forEach(function(type) {
        rows.push(labels[type] + ': ' + (latest[type] ? when(latest[type]) : scanned ? 'not seen in examined logs' : 'unknown; logs unavailable'));
    });
    if (latest.error && latest.report) rows.push('Successful report upload after last recognized error: ' + (latest.report.time > latest.error.time ? 'yes' : 'not seen'));
    if (latest.registration && latest.registration.endpoint) {
        probeTarget = latest.registration.endpoint;
        rows.push('Last registered relay: ' + describe(probeTarget));
    }
    rows.push('Report uploads and site synchronization are separate events; no server-console or compliance status was queried.');
    if (probeTarget) rows.push('__BIGFIX_PROBE_TARGET__ ' + probeTarget.host + ' ' + probeTarget.port);
    return rows.join('\n');
}
BIGFIX_JXA
) || REPORT_BIGFIX_DETAIL='BigFix configuration/log status could not be read.'
printf '%s\n' "$REPORT_BIGFIX_DETAIL" | /usr/bin/awk '!/^__BIGFIX_PROBE_TARGET__ /'
if [[ $REPORT_PROBE_BIGFIX -eq 1 ]]; then
    REPORT_BIGFIX_HOST=$(printf '%s\n' "$REPORT_BIGFIX_DETAIL" | /usr/bin/awk '/^__BIGFIX_PROBE_TARGET__ / { print $2; exit }')
    REPORT_BIGFIX_PORT=$(printf '%s\n' "$REPORT_BIGFIX_DETAIL" | /usr/bin/awk '/^__BIGFIX_PROBE_TARGET__ / { print $3; exit }')
    if [[ "$REPORT_BIGFIX_HOST" =~ ^([A-Za-z0-9][A-Za-z0-9._-]*|[A-Fa-f0-9:]+)$ && "$REPORT_BIGFIX_PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$REPORT_BIGFIX_PORT >= 1 && 10#$REPORT_BIGFIX_PORT <= 65535 )); then
        if /usr/bin/nc -z -G 3 -w 3 "$REPORT_BIGFIX_HOST" "$REPORT_BIGFIX_PORT" </dev/null >/dev/null 2>&1; then
            printf 'Live relay TCP probe: reachable (%s, port %s)\n' "$REPORT_BIGFIX_HOST" "$REPORT_BIGFIX_PORT"
        else
            printf 'Live relay TCP probe: connection could not be established (%s, port %s)\n' "$REPORT_BIGFIX_HOST" "$REPORT_BIGFIX_PORT"
        fi
        printf 'TCP reachability alone does not verify authenticated BigFix reporting; VPN/proxy routing may differ.\n'
    else
        printf 'Live relay TCP probe: unavailable; no recognized relay endpoint found\n'
    fi
else
    printf 'Live relay TCP probe: skipped; use --probe-bigfix to enable\n'
fi

section 'Relevant configuration profile names and organizations'
REPORT_PROFILE_PARSER=$(/bin/cat <<'JXA'
ObjC.import('Foundation');
function run() {
    var rows = [], seen = {};
    var pattern = /falcon|crowdstrike|fireeye|trellix|bigfix|forescout|jamf|globalprotect|intune|defender|symantec|sophos|sentinel|carbon|cylance|security|privacy|pppc|filevault|firewall|vpn|mdm|enrollment|restrictions/i;
    function safe(value) {
        return String(value || '(unspecified)').replace(/\/Users\/[^\/\s]+/g, '/Users/[redacted]').replace(/[\w.%+-]+@[\w.-]+\.[a-z]{2,}/gi, '[email redacted]').replace(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/gi, '[UUID redacted]');
    }
    function walk(value) {
        if (!value || typeof value !== 'object') return;
        if (Array.isArray(value)) { value.forEach(walk); return; }
        if (value.spconfigprofile_profile_identifier && pattern.test(value._name || value.spconfigprofile_profile_identifier)) {
            var row = safe(value._name) + ' | organization: ' + safe(value.spconfigprofile_organization);
            if (!seen[row]) { seen[row] = true; rows.push(row); }
        }
        Object.keys(value).forEach(function(key) { walk(value[key]); });
    }
    try {
        var input = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
        walk(JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(input, $.NSUTF8StringEncoding))));
        return rows.length ? rows.join('\n') : 'No matching profiles returned with current permissions.';
    } catch (e) { return 'Profile summary unavailable with current permissions.'; }
}
JXA
)
if ! /usr/sbin/system_profiler -timeout 15 SPConfigurationProfileDataType -json 2>/dev/null | /usr/bin/osascript -l JavaScript -e "$REPORT_PROFILE_PARSER" 2>/dev/null; then
    printf 'Profile summary could not be completed.\n'
fi

section 'Security-agent privacy permissions configured by MDM'
/usr/bin/osascript -l JavaScript <<'JXA'
ObjC.import('Foundation');
function run() {
    var path = '/Library/Application Support/com.apple.TCC/MDMOverrides.plist';
    var data = $.NSData.dataWithContentsOfFile(path);
    if (!data) return 'MDM privacy overrides not found or not readable with current permissions.';
    var services = {
        kTCCServiceSystemPolicyAllFiles: 'Full Disk Access',
        kTCCServiceAccessibility: 'Accessibility',
        kTCCServiceScreenCapture: 'Screen recording',
        kTCCServiceListenEvent: 'Input monitoring'
    };
    var rows = [];
    try {
        var config = ObjC.deepUnwrap($.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 0, Ref(), Ref()));
        Object.keys(config).sort().forEach(function(client) {
            if (!/crowdstrike|falcon|fireeye|trellix|bigfix|besagent|forescout|jamf|globalprotect|defender|symantec|sophos|sentinel|cylance/i.test(client)) return;
            Object.keys(services).forEach(function(service) {
                var policy = config[client][service];
                if (!policy) return;
                var decision = 'configured (decision not recognized)';
                if (policy.Allowed === true || policy.Allowed === 1 || policy.Authorization === 'Allow') decision = 'allowed by MDM';
                else if (policy.Allowed === false || policy.Allowed === 0 || policy.Authorization === 'Deny') decision = 'denied by MDM';
                else if (policy.Authorization === 'AllowStandardUserToSetSystemService') decision = 'MDM lets the user decide; not an automatic grant';
                var label = client.replace(/\/Users\/[^\/\s]+/g, '/Users/[redacted]');
                rows.push(services[service] + ' | ' + label + ' | ' + decision);
            });
        });
        return rows.length ? rows.join('\n') : 'No matching MDM privacy overrides found.';
    } catch (e) { return 'MDM privacy overrides could not be read.'; }
}
JXA

section 'Security-agent privacy decisions stored in the system TCC database'
printf 'Stored direct decisions can be overridden by the MDM policies above.\n'
printf 'These records do not establish effective runtime access or an active remote session.\n'
REPORT_TCC_SQL=$(/bin/cat <<'SQL'
SELECT CASE service WHEN 'kTCCServiceSystemPolicyAllFiles' THEN 'Full Disk Access'
                    WHEN 'kTCCServiceAccessibility' THEN 'Accessibility'
                    WHEN 'kTCCServiceScreenCapture' THEN 'Screen recording'
                    WHEN 'kTCCServiceListenEvent' THEN 'Input monitoring' END, client,
       CASE auth_value WHEN 0 THEN 'denied' WHEN 1 THEN 'unknown'
            WHEN 2 THEN 'allowed' WHEN 3 THEN 'limited' ELSE 'other' END
FROM access
WHERE service IN ('kTCCServiceSystemPolicyAllFiles', 'kTCCServiceAccessibility',
                  'kTCCServiceScreenCapture', 'kTCCServiceListenEvent')
  AND (lower(client) LIKE '%crowdstrike%' OR lower(client) LIKE '%falcon%'
       OR lower(client) LIKE '%fireeye%' OR lower(client) LIKE '%trellix%'
       OR lower(client) LIKE '%bigfix%' OR lower(client) LIKE '%besagent%'
       OR lower(client) LIKE '%forescout%' OR lower(client) LIKE '%jamf%'
       OR lower(client) LIKE '%globalprotect%' OR lower(client) LIKE '%defender%'
       OR lower(client) LIKE '%symantec%' OR lower(client) LIKE '%sophos%'
       OR lower(client) LIKE '%sentinel%' OR lower(client) LIKE '%cylance%')
ORDER BY client, service;
SQL
)
if REPORT_TCC=$(/usr/bin/sqlite3 -readonly -separator ' | ' '/Library/Application Support/com.apple.TCC/TCC.db' "$REPORT_TCC_SQL" 2>/dev/null); then
    if [[ -n "$REPORT_TCC" ]]; then
        printf '%s\n' "$REPORT_TCC" | redact
    else
        printf 'No matching records in the system database; user-level permissions were not queried.\n'
    fi
else
    printf 'Unavailable; sudo and/or Full Disk Access for the terminal may be needed.\n'
fi

section 'CrowdStrike local health statistics (administrator mode)'
if [[ $EUID -ne 0 ]]; then
    printf 'Skipped; run with sudo for this check.\n'
elif [[ ! -x '/Applications/Falcon.app/Contents/Resources/falconctl' ]]; then
    printf 'Falcon command-line tool not found.\n'
else
    # Whitelist status fields. Never print raw stats (they can include tenant/host IDs).
    REPORT_FALCON=$('/Applications/Falcon.app/Contents/Resources/falconctl' stats 2>/dev/null) || REPORT_FALCON=''
    REPORT_HEALTH=$(printf '%s\n' "$REPORT_FALCON" | /usr/bin/grep -Ei '^[[:space:]]*(sensor operational|sensor version|version|connection state|connected|full disk access|sensor has full disk access|reduced functionality mode|rfm)[[:space:]]*[:=][[:space:]]*([0-9.]+|true|false|yes|no|connected|disconnected|enabled|disabled|operational)[[:space:]]*$') || REPORT_HEALTH=''
    if [[ -n "$REPORT_HEALTH" ]]; then
        printf '%s\n' "$REPORT_HEALTH"
    else
        printf 'No recognized status fields returned; local/cloud health could not be established.\n'
    fi
fi

section 'Built-in macOS protections'
check 'FileVault' /usr/bin/fdesetup status
check 'Gatekeeper' /usr/sbin/spctl --status
check 'Application firewall' /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
check 'System Integrity Protection' /usr/bin/csrutil status

section 'Matching installation receipts (historical; do not prove current installation)'
if ! /usr/sbin/pkgutil --pkgs 2>/dev/null | /usr/bin/grep -Ei "$REPORT_PATTERN|edu\.ucsf|sycomp" | /usr/bin/sort -u; then
    printf 'No matching receipts found, or receipt listing unavailable.\n'
fi

printf '\nEnd of report. No configuration changes were requested.\n'
