# VPS Blocker 
# Advanced VPN Detection & FiveM Authentication

A comprehensive FiveM resource that detects and blocks VPN/proxy connections while requiring FiveM account authentication. 
Features intelligent IP caching, database logging, Discord webhooks via qb-logs, and in-game whitelist management.

> **Note:** This resource supports `qb-logs` for both `qb-core` and `qbox_core` <br>
> (when running in qb-core compatibility mode).<br>
> A compatible `qb-logs` is included with this resource for convenience.

## 🚀 Features

- **VPN/Proxy Detection** - Uses ip-api.com to detect and block VPN connections
- **Smart IP Caching** - Bypasses API checks for previously verified clean IPs
- **FiveM Authentication** - Requires players to be logged into FiveM/CFX
- **Whitelist System** - Bypass all checks for approved players
- **Database Logging** - Tracks all connection attempts with IP and proxy status
- **Discord Integration** - Sends denial logs to Discord via qb-logs
- **In-Game Management** - Add/remove whitelist entries without editing files
- **Auto-Sync on Restart** - Updates database with all connected players on resource start
- **Debug Mode** - Toggle detailed console logging

---

## 📦 Installation

1. **Download** and place in your `resources` folder
2. **Import SQL** - Run `database.sql` in your MySQL database
3. **Add to server.cfg**:
   ```
   ensure oxmysql
   ensure qb-logs   # Use the included qb-logs or your own compatible version
   ensure vps_blocker
   ```
4. **Configure** - Edit `config.lua` to customize settings

---

## ⚙️ Configuration

### Basic Settings

```lua
Config.ServerName = 'Your Server Name'
Config.Debug = false  -- Enable debug console logging
Config.UseQbxLogs = true  -- Send logs to qb-logs/Discord
```

### Localization

```lua
Config.Locales = {
    VPN_Detected = 'VPN Detected',
    VPN_Detected_Message = 'Your custom message...',
    API_Error = 'API Error message...',
}
```

### Whitelist

Add identifiers manually in config or use in-game commands:

```lua
Config.Whitelist = {
    'license2:xxxxxxxxxxxxx',
    'discord:123456789',
    'license:xxxxxxxxxxxxx',
}
```

---

## 🎮 Commands

### `/vpnwhitelist` - Manage Whitelist
**Permission Required:** `group.admin`

**Usage:**
```
/vpnwhitelist list
/vpnwhitelist add <player id or identifier>
/vpnwhitelist remove <identifier or list number>
```

**Examples:**
```
/vpnwhitelist list
/vpnwhitelist add 5
/vpnwhitelist add license2:
/vpnwhitelist remove 1
/vpnwhitelist remove license2:
```

**Features:**
- Auto-detects license2 identifier from player ID
- Changes are saved to config.lua automatically
- Changes take effect immediately (no restart needed)

### `/vpnrestart` - Reload Resource
**Permission Required:** `group.admin`

Restarts the vps_blocker resource to reload configuration.

---

## 🔐 How It Works

### Connection Flow

1. **Whitelist Check** (First Priority)
   - If player is whitelisted → ✅ **Allowed** (all checks bypassed)

2. **FiveM Identifier Check**
   - If player has valid `fivem:` identifier → Continue
   - If no FiveM ID → ❌ **Blocked** (shown: "Login to FiveM/CFX and try again")

3. **Database Cache Check** (Smart Bypass)
   - If IP exists in database with `is_proxy = 0` → ✅ **Allowed** (API check skipped)
   - This speeds up connections for returning legitimate players
   - Updates timestamp and identifiers automatically

4. **VPN Detection Check** (Only if not cached)
   - Player IP checked against ip-api.com API
   - If VPN/Proxy detected → ❌ **Blocked** (shown: VPN message + Discord link)
   - If no VPN → ✅ **Allowed** and cached for future connections

5. **Database Logging**
   - All connection attempts are logged to `vps_blocker_logs` table
   - Tracks: identifiers, IP, proxy status, timestamp
   - Updates existing records on reconnection

6. **Discord Notification** (if enabled)
   - Blocked connections trigger qb-logs webhook
   - Includes: player name, reason, IP, all identifiers

---

## 🗄️ Database

### Table: `vps_blocker_logs`

```sql
CREATE TABLE `vps_blocker_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifiers` TEXT NOT NULL,
    `ip` VARCHAR(50) NOT NULL,
    `is_proxy` TINYINT(1) NOT NULL DEFAULT 0,
    `timestamp` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `ip_index` (`ip`),
    KEY `timestamp_index` (`timestamp`)
)
```

**Fields:**
- `identifiers` - JSON array of all player identifiers
- `ip` - Player's IP address
- `is_proxy` - 1 if VPN/proxy detected, 0 if clean
- `timestamp` - Last connection attempt

**Performance:**
- Indexed on `ip` for fast cache lookups
- Indexed on `timestamp` for query optimization

---

## ⚡ Smart IP Caching System

### How It Works
When a player connects:
1. System checks if their IP exists in database with `is_proxy = 0`
2. If found → **Instant connection** (no API call needed)
3. If not found → Queries API and caches result

### Benefits
- **Faster connections** for returning players
- **Reduces API calls** (saves rate limit)
- **Lower latency** for legitimate players
- **Automatic updates** of player identifiers

### Cache Invalidation
- Records never expire automatically
- Admins can manually remove IPs from database if needed
- VPN IPs (`is_proxy = 1`) are NOT cached for bypass

---

## 🔧 Advanced Features

### Auto-Update on Restart
When the resource starts, it automatically:
- Scans all currently connected players
- Checks their IP against VPN API
- Updates or inserts records in database
- Rebuilds IP cache

### Persistent Whitelist
- Whitelist changes via `/vpnwhitelist` are saved to `config.lua`
- Changes persist after server restart
- No manual file editing required

### qb-logs Integration
#### qb-logs Setup for Logging

To enable Discord logging, configure your `qb-logs` (included or compatible) with a webhook for VPN Blocker:

```lua
['vpn_blocker'] = 'YOUR_DISCORD_WEBHOOK_URL'
```

**Supported Frameworks:**
- `qb-core` (standard)
- `qbox_core` (when using qb-core compatibility mode)

**Logs include:**
- Player name
- Denial reason (No FiveM ID / VPN Detected)
- IP address
- All player identifiers

---

## 🔍 Identifier Types Supported

- `fivem:` - FiveM account ID (required for non-whitelisted)
- `license2:` - FiveM license (recommended for whitelist)
- `license:` - Legacy license
- `discord:` - Discord user ID
- `xbl:` - Xbox Live ID
- `live:` - Microsoft Live ID

---

## 🛠️ Troubleshooting

### Players can't join without FiveM login
✅ **Expected behavior** - Non-whitelisted players must be logged into FiveM
💡 **Solution:** Add them to whitelist or ask them to login to FiveM launcher

### False positives on cloud gaming
💡 **Solution:** Use `/vpnwhitelist add <player id>` to bypass checks
💡 **Solution:** Use `/vpnwhitelist add Identifier` to bypass checks

### API errors
- Check server internet connection
- Verify ip-api.com is accessible
- Enable `Config.Debug = true` for detailed logs
- Rate limit: 45 requests/minute on free tier (caching reduces usage)

### Discord logs not working
- Ensure `qb-logs` is started before `vps_blocker`
- Add the `vpn_blocker` webhook to your qb-logs config (see above)
- Set `Config.UseQbxLogs = true` in your config.lua

### Whitelist not saving
- Check file permissions on `config.lua`
- Resource needs write access to its own folder

### IP cache not working
- Verify MySQL connection is active
- Check database table has proper indexes
- Enable debug mode to see cache hits/misses

---

## 📝 Permissions Setup

Add to your `permissions.cfg`:

```properties
# VPN Blocker Admin Access
add_ace group.admin admin allow
add_principal identifier.license:YOUR_LICENSE group.admin
```

---

## 📊 Debug Mode

Enable detailed logging:
```lua
Config.Debug = true
```

Shows:
- All player identifiers on connection
- Whitelist check results
- FiveM identifier validation
- Database cache hits/misses
- VPN API responses (when called)
- Database operations

---

## 🌐 API Information

**Provider:** ip-api.com  
**Endpoint:** `http://ip-api.com/json/`  
**Rate Limit:** 45 requests/minute (free)  
**Fields Used:** Full dataset (66846719)

**Smart Caching Benefits:**
- Reduces API calls by ~70-90% for established servers
- Only new/VPN IPs trigger API requests
- Returning legitimate players connect instantly

---

## 📜 License

Check [LICENSE](LICENSE) file for details.


---

## 🔄 Changelog

### v2.1.0
- Added smart IP caching system
- Drastically improved connection speed for returning players
- Reduced API calls by up to 90%
- Added database indexes for performance

### v2.0.0
- Added database logging
- Added qb-logs integration
- Added in-game whitelist management commands
- Added auto-sync on resource start
- Added persistent whitelist saving
- Improved permission system
- Added debug mode toggle

### v1.0.0
- Initial release
- VPN detection
- FiveM authentication
- Basic whitelist system

---

## 💡 Performance Tips

1. **Regular players benefit most** - The more returning players, the better caching performs
2. **Database maintenance** - Periodically clean old records if needed
3. **Whitelist trusted players** - Bypasses all checks for best performance
4. **Monitor API usage** - Debug mode shows when API calls are made

---

## ⚠️ Important Notes

- IP cache only applies to clean IPs (`is_proxy = 0`)
- VPN/proxy IPs are always checked via API
- Whitelist still bypasses ALL checks (fastest option)
- Database must be properly configured for caching to work


---

## 🙏 Original Creator

This project is based on the original work by [CADOJRP](https://github.com/CADOJRP/FiveM-BlockVPN/tree/master). All credit for the initial development and concept goes to them.

# BlockVPN for FiveM v1.0.4

BlockVPN is a simple and effective script for FiveM servers that blocks players using VPNs or proxies from joining your server. It uses the GetIPIntel API to detect VPN/proxy usage and helps keep your community safe from unwanted connections.

## Features
- Detects and blocks most VPN and proxy connections
- Customizable kick threshold and reason
- Caching to reduce API requests
- Bypass permission for trusted users
- Easy to configure

## Installation
1. Download or clone this repository into your FiveM resources folder.
2. Add `start blockVPN` (or `ensure blockVPN`) to your `server.cfg`.
3. Make sure your server has internet access to use the GetIPIntel API.

## Configuration
Open `blockVPN/server.lua` and edit the following settings at the top of the file:

- `ownerEmail`: **(Required)** Your contact email for GetIPIntel API (no account needed, just an email for contact).
- `kickThreshold`: Probability threshold for blocking (default: 0.99).
- `kickReason`: Message shown to blocked players.
- `flags`: API check flags (default: 'm' for blacklist check).
- `printFailed`: Print blocked attempts to server console (true/false).
- `cacheTime`: How long (in seconds) to cache IP results (default: 8 hours).

### Example:
```lua
local ownerEmail = 'your@email.com'  -- Set this to your email
local kickThreshold = 0.99           -- Recommended minimum
local kickReason = 'VPN/Proxy detected. Contact staff if this is a mistake.'
local flags = 'm'
local printFailed = true
local cacheTime = 8 * 3600
```

## Permissions
To allow certain players (e.g., staff) to bypass the VPN check, give them the `blockVPN.bypass` ACE permission in your server configuration.

## How It Works
When a player connects, their IP is checked against the GetIPIntel API. If the probability of VPN/proxy use is above your threshold, they are kicked with your custom message. Results are cached to reduce API calls.

## License
This project is licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file for details.

## Credits
- Script by original author(s)
- Uses [GetIPIntel](https://getipintel.net/) for VPN/proxy detection

---
## Primary Purpose
Block VPN and proxy connections to your FiveM server.


---
