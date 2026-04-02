# Setup Guide

Step-by-step instructions for setting up a Mac Mini M4 as a headless AI workstation.
`setup.sh` automates software installation (Phase 5), but the remaining phases require
manual configuration through System Settings or physical access.

---

## Phase 1: Initial Setup (with a temporary monitor)

You need a monitor, keyboard, and mouse for the first 30 minutes. After that, everything is remote.

- [ ] Unbox and connect HDMI to a temporary monitor, plus keyboard and mouse
- [ ] Power on, complete macOS Setup Assistant
  - Sign in with your Apple ID
  - Connect to your designated network / VLAN
  - Skip iCloud Desktop & Documents sync (saves SSD space)
  - Enable FileVault disk encryption when prompted
- [ ] Run **System Settings > General > Software Update** and install all pending updates
- [ ] Reboot after updates complete

---

## Phase 2: Always-On Configuration

These settings ensure the Mac stays awake, recovers from power loss, and is always reachable.

### Energy Settings

System Settings > Energy:

- [ ] **Prevent automatic sleeping when the display is off** > On
- [ ] **Put hard disks to sleep when possible** > Off
- [ ] **Wake for network access** > On
- [ ] **Start up automatically after a power failure** > On

### Automatic Login

System Settings > Users & Groups:

- [ ] Set **Automatic Login** to your user account
- [ ] Note: if FileVault is enabled, you still get a pre-boot login screen after a cold
  start — this is expected and unavoidable, but once authenticated the system will
  auto-login on normal reboots

### Disable Sleep Entirely (Belt and Braces)

Open Terminal and run:

```bash
sudo pmset -a sleep 0
sudo pmset -a disksleep 0
sudo pmset -a displaysleep 0
sudo pmset -a hibernatemode 0
```

Verify with:

```bash
pmset -g
```

Confirm `sleep`, `disksleep`, and `displaysleep` all show `0`.

---

## Phase 3: Remote Access

### Screen Sharing (Primary)

System Settings > General > Sharing:

- [ ] **Screen Sharing** > On
- [ ] Click the info button (i) next to Screen Sharing
  - Allow access for: your user account
  - Note the address shown (e.g. `vnc://192.168.x.x`)

### SSH (Backup access)

System Settings > General > Sharing:

- [ ] **Remote Login** > On
- [ ] Allow access for: your user account

### Remote Management (Optional but useful)

System Settings > General > Sharing:

- [ ] **Remote Management** > On (enables Apple Remote Desktop features like remote reboot)

### Test Remote Access Before Disconnecting the Monitor

- [ ] From another Mac on the same network (or via VPN):
  - Open **Finder > Go > Connect to Server** (Cmd+K)
  - Enter `vnc://[mac-mini-ip]`
  - Confirm you can see and control the desktop
- [ ] Test SSH: `ssh yourusername@[mac-mini-ip]`
- [ ] Only once both work: disconnect the monitor, keyboard, and mouse

---

## Phase 4: HDMI Dummy Plug / Virtual Display

Without a physical display, macOS defaults to a low resolution over Screen Sharing.
Fix this with one of these options:

### Option A: HDMI Dummy Plug (Simplest)

- [ ] Purchase an HDMI dummy plug / display emulator (search "HDMI dummy plug 4K")
- [ ] Plug it into the HDMI port on the Mac Mini
- [ ] macOS will think a 4K display is attached
- [ ] Screen Sharing will now offer proper resolutions (1920x1080, 2560x1440, etc.)

### Option B: BetterDisplay (Software solution, no dongle needed)

`setup.sh` installs BetterDisplay automatically. After running the script:

- [ ] Open BetterDisplay > Create a new virtual display
- [ ] Set resolution to 2560x1440 or your preference
- [ ] Configure it to create the virtual display automatically on login

---

## Phase 5: Install Core Tools (Automated)

This phase is fully handled by `setup.sh`. See the [README](README.md) for usage.

The script installs: Homebrew, Node.js (via nvm), CLI tools (git, gh, tmux, shellcheck,
shfmt, lefthook, commitlint, uv, ruff, etc.), desktop apps (Brave, Rectangle, iTerm2,
VS Code, Claude Desktop, BetterDisplay), Oh My Zsh with plugins, VS Code extensions and
settings, project templates, and headless macOS optimisations.

```bash
chmod +x setup.sh
./setup.sh
```

---

## Phase 6: macOS Hardening for Server Use

### Disable Unnecessary Services

- [ ] **System Settings > Notifications** > Turn off notifications you don't need
  (prevents visual clutter during Screen Sharing)
- [ ] **System Settings > Desktop & Dock > Hot Corners** > Set all to nothing
  (avoids accidental triggers during remote sessions)

### Software Updates

System Settings > General > Software Update > Automatic Updates:

- [ ] **Download new updates when available** > On
- [ ] **Install macOS updates** > Off (you want to control when reboots happen)
- [ ] **Install application updates from the App Store** > On
- [ ] **Install Security Responses and system files** > On

### Firewall

System Settings > Network > Firewall:

- [ ] **Firewall** > On
- [ ] Click **Options**: ensure Screen Sharing and Remote Login are allowed through

### Accessibility Permissions

System Settings > Privacy & Security > Accessibility:

- [ ] Add **Rectangle** (required for window management shortcuts)

### Full Disk Access

System Settings > Privacy & Security > Full Disk Access:

- [ ] Add **iTerm** and **Visual Studio Code**
- [ ] Without this, macOS will pop permission dialogs that block the apps when no one
  is at the screen

---

## Phase 7: Network Configuration

If you are using a managed network (e.g. Unifi), configure the following:

- [ ] Assign the Mac Mini a **static IP** (or a DHCP reservation)
- [ ] Create firewall rules to allow:
  - **VNC / Screen Sharing** (TCP 5900) from your client network
  - **SSH** (TCP 22) from your client network
  - **Outbound HTTPS** (TCP 443) for API access and updates
- [ ] If using a VPN:
  - Ensure VPN clients can reach the Mac Mini's network
  - Test Screen Sharing from your phone (e.g. Screens 5 or RealVNC Viewer)

---

## Phase 8: Quality-of-Life Extras

### Keep-Alive Monitoring (Optional)

If you want to know when the Mac Mini goes offline:

- [ ] Set up a ping monitor against the static IP (many routers support this natively)
- [ ] Alternatively, use a free uptime monitoring service against an SSH or HTTP port

### Scheduled Maintenance

- [ ] Set a recurring reminder (fortnightly) to:
  - Check for macOS updates and install during downtime
  - Run `brew update && brew upgrade` for tool updates
  - Check SSD usage: `df -h /`

---

## Phase 9: Post-Setup Verification

Run through this checklist after the Mac Mini is in its permanent location:

- [ ] Disconnect monitor, keyboard, mouse — Mac Mini running headless
- [ ] From another Mac via local network: Screen Sharing connects and resolution is good
- [ ] From another Mac via VPN: Screen Sharing connects
- [ ] From mobile via VPN: Screen Sharing connects
- [ ] SSH works: `ssh yourusername@[static-ip]`
- [ ] Claude Desktop opens and responds in Screen Sharing session
- [ ] Claude Code runs in Terminal or VS Code
- [ ] Simulate a power cut: unplug, plug back in, confirm it boots and auto-logs in
- [ ] Confirm the machine hasn't slept after leaving it idle for 2+ hours

---

## Quick Reference

| Detail             | Value                     |
|--------------------|---------------------------|
| Mac Mini IP        | `192.168.x.x` *(fill in)* |
| VLAN               | *(fill in)*               |
| Username           | *(fill in)*               |
| Screen Sharing     | `vnc://192.168.x.x`       |
| SSH                | `ssh user@192.168.x.x`    |
| Annual power cost  | ~£12-15 (5-7W idle)       |
