# Hive Siren V2 Driver - Complete Testing Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Step 1: Install SmartThings CLI](#step-1-install-smartthings-cli)
3. [Step 2: Package and Upload the Driver](#step-2-package-and-upload-the-driver)
4. [Step 3: Install on Hub](#step-3-install-on-hub)
5. [Step 4: Pair Test Device](#step-4-pair-test-device)
6. [Step 5: Verify Child Devices Created](#step-5-verify-child-devices-created)
7. [Step 6: Test Alarm Functionality](#step-6-test-alarm-functionality)
8. [Step 7: Test Light Functionality](#step-7-test-light-functionality)
9. [Step 8: Monitor Driver Logs](#step-8-monitor-driver-logs)
10. [Troubleshooting](#troubleshooting)
11. [Rollback Plan](#rollback-plan)

---

## Prerequisites

### What You Need
- ✅ macOS computer with terminal access
- ✅ SmartThings Hub (already have this)
- ✅ SmartThings account (already have this)
- ✅ Node.js installed (for SmartThings CLI)
- ✅ A test Hive Siren device (NEW device OR one you can reset)

### Safety First! 🛡️
**IMPORTANT**: Your two existing sirens will NOT be affected!
- They continue using the original driver
- V2 is a separate driver package
- Test with a third device or temporarily unpair ONE existing device

---

## Step 1: Install SmartThings CLI

### Check if Already Installed
```bash
smartthings --version
```

If you see a version number (e.g., `@smartthings/cli/1.x.x`), skip to Step 2.

### Install SmartThings CLI (if needed)
```bash
npm install -g @smartthings/cli
```

### Authentication
**Note:** There is no separate `login` command. Authentication happens automatically when you run your first SmartThings CLI command. The CLI will:
1. Open your web browser
2. Ask you to log in to SmartThings
3. Grant CLI access
4. Save authentication token for future use

---

## Step 2: Package and Upload the Driver

### Navigate to V2 Driver Directory
```bash
cd /Users/satinder/Documents/siren/hive-siren-smartthings-driver-v2
```

### Verify Files Exist
```bash
ls -la
```

You should see:
- `config.yml`
- `fingerprints.yml`
- `src/init.lua`
- `profiles/hive-siren.yml`
- `profiles/hive-siren-alarm.yml`
- `profiles/hive-siren-light.yml`

### Package and Upload Driver
```bash
smartthings edge:drivers:package -a
```

This single command will:
1. Package the driver
2. Upload it to SmartThings
3. Prompt you to select a channel (or use your default)
4. Assign the driver to that channel

**Expected Output:**
```
───────────────────────────────────────────────────
 Driver Id    xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx
 Name         Hive Siren
 Package Key  hive-siren
 Version      2026-02-14T22:36:16.884147292
───────────────────────────────────────────────────
 #  Name               Channel Id
────────────────────────────────────────────────────
 1  My Custom Channel  yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyy
────────────────────────────────────────────────────
? Select a channel for the driver. 1
assigned driver to channel
```

**📝 IMPORTANT:** Copy the Driver ID from the output - you'll need it for logging!

**Note:** If you don't have a channel yet, create one first:
```bash
smartthings edge:channels:create
```
Follow the prompts to create a "self-publish" channel.

**If you get errors:**
- Check that all YAML files have correct syntax
- Ensure `config.yml` has correct driver name
- Verify Lua file has no syntax errors

---

## Step 3: Install on Hub

### List Your Hubs
```bash
smartthings edge:drivers:installed -H
```

**Expected Output:**
```
┌────────────────────────────────────┬────────────┬────────┐
│ Hub ID                             │ Name       │ Status │
├────────────────────────────────────┼────────────┼────────┤
│ yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyy   │ My Hub     │ ONLINE │
└────────────────────────────────────┴────────────┴────────┘
```

### Enroll Hub in Your Channel (if not already enrolled)
```bash
smartthings edge:channels:enroll
```

Select:
1. Your hub (from list)
2. Your channel (from list)

### Install Driver on Hub

**Option A: Via SmartThings Mobile App (Recommended)**
1. Open SmartThings app on your phone
2. Go to **Menu (☰)** → **Settings**
3. Tap **Driver**
4. Find your channel name
5. Tap **Available Drivers**
6. Find "Hive Siren" (v2 or updated timestamp)
7. Tap **Install**
8. Wait 1-2 minutes for installation

**Option B: Via CLI**
```bash
smartthings edge:drivers:install <DRIVER_ID> -H <HUB_ID>
```

Replace:
- `<DRIVER_ID>`: The Driver ID from Step 3
- `<HUB_ID>`: Your Hub ID from above

### Verify Installation
```bash
smartthings edge:drivers:installed -H <HUB_ID>
```

You should see the Hive Siren driver in the list.

---

## Step 4: Pair Test Device

### ⚠️ Safety Check
- [ ] Verified your two existing sirens are still working?
- [ ] Have a NEW/third Hive Siren OR one you can safely reset?
- [ ] Understand this won't affect existing devices?

### Reset Hive Siren (if needed)
1. Remove batteries from the siren
2. Hold the **reset button** (small hole on back)
3. While holding, insert batteries
4. Keep holding for **10 seconds**
5. LED should flash rapidly → device reset

### Pair Device to SmartThings

**Using SmartThings Mobile App:**
1. Open SmartThings app
2. Tap **Devices** (bottom)
3. Tap **+** (top right)
4. Tap **Add Device**
5. Tap **Scan nearby**
6. Wait for "Hive Siren" to appear
7. Tap to add it

**Alternative Method:**
1. Go to **Devices** → **+** → **Add Device**
2. Tap **By brand** → Search "Hive"
3. Select "Hive Siren"
4. Follow pairing instructions

### Driver Selection
- If prompted to choose a driver, select the **newer version** (latest timestamp)
- The V2 driver should be automatically selected if it matches the fingerprint

### Wait for Pairing
- Pairing takes **30-60 seconds**
- Hub LED will flash during pairing
- You should see "Device added successfully"

---

## Step 5: Verify Child Devices Created

### Check in SmartThings App

After pairing, you should see **THREE devices** appear:

1. **"Hive Siren"** (Parent Device)
   - May not show many controls (this is normal)
   - Battery level visible

2. **"Hive Siren - Alarm"** (Child Device)
   - Alarm controls: Off, Siren, Strobe, Both
   - Battery level
   - Refresh button

3. **"Hive Siren - Light"** (Child Device)
   - On/Off switch
   - Brightness slider (0-100%)
   - Refresh button

### ✅ Success Criteria
- [ ] Three devices visible in SmartThings app
- [ ] Alarm device shows alarm capability
- [ ] Light device shows switch and level capabilities
- [ ] Each device has unique name

### ❌ If Only ONE Device Appears
This means child devices weren't created:
- Check driver logs (Step 9)
- Look for "Creating child devices for parent" message
- May need to delete and re-pair device

---

## Step 6: Test Alarm Functionality

### Test on "Hive Siren - Alarm" Device

Open the **"Hive Siren - Alarm"** device in the app.

#### Test 1: OFF Command
1. Tap **OFF**
2. **Expected:** No sound, light turns off
3. **Status:** Alarm shows "off"

#### Test 2: SIREN Command (Audio Only)
1. Tap **SIREN**
2. **Expected:**
   - Loud siren sound (emergency tone)
   - No flashing light
   - Runs for 60 seconds
3. **Status:** Alarm shows "siren"
4. **To Stop:** Tap OFF

#### Test 3: STROBE Command (Visual + Audio) - **THE FIX!**
1. Tap **STROBE**
2. **Expected:**
   - ✅ Audio beeping/siren sound
   - ✅ Flashing flood light (visual alert)
   - Both should work together!
3. **Status:** Alarm shows "strobe"
4. **To Stop:** Tap OFF

**This is the FIXED behavior!** Previously strobe produced beeps without light flashing.

#### Test 4: BOTH Command (Maximum Alert)
1. Tap **BOTH**
2. **Expected:**
   - Loud siren sound (maximum volume)
   - Bright flashing flood light (maximum intensity)
   - Full alarm mode
3. **Status:** Alarm shows "both"
4. **To Stop:** Tap OFF

#### Test 5: Battery Display
- Check battery percentage shows correctly
- Should be near 100% for new batteries

### ✅ Alarm Test Checklist
- [ ] OFF command stops all sound and light
- [ ] SIREN produces audio only
- [ ] STROBE produces audio + flashing light (FIXED!)
- [ ] BOTH produces maximum audio + light
- [ ] Battery level displays correctly
- [ ] Can stop alarm at any time with OFF

---

## Step 7: Test Light Functionality

### Test on "Hive Siren - Light" Device

Open the **"Hive Siren - Light"** device in the app.

#### Test 1: Turn Light ON
1. Tap the **switch** to ON
2. **Expected:** Flood light turns on at last brightness level
3. **Status:** Switch shows "On"

#### Test 2: Turn Light OFF
1. Tap the **switch** to OFF
2. **Expected:** Flood light turns off
3. **Status:** Switch shows "Off"

#### Test 3: Adjust Brightness (While ON)
1. Turn light ON
2. Move **brightness slider** to 25%
3. **Expected:** Light dims to 25%
4. Move slider to 75%
5. **Expected:** Light brightens to 75%
6. Move slider to 100%
7. **Expected:** Light at full brightness

#### Test 4: Brightness Persistence
1. Set light to 50%
2. Turn OFF
3. Turn ON again
4. **Expected:** Light turns on at 50% (or possibly 100%, depends on device memory)

### ✅ Light Test Checklist
- [ ] Light turns on/off correctly
- [ ] Brightness slider works (0-100%)
- [ ] Light responds within 1-2 seconds
- [ ] No interference with alarm device

---

## Step 8: Monitor Driver Logs

### Start Live Logging

**Option A: View All Logs**
```bash
smartthings edge:drivers:logcat
```

Select your hub when prompted.

**Option B: View Specific Driver Logs**
```bash
smartthings edge:drivers:logcat <DRIVER_ID> --hub-address <HUB_ID>
```

### What to Look For

#### During Device Pairing:
```
INFO Hive Siren added: <device-id>
INFO Creating child devices for parent: <device-id>
INFO Created alarm child device
INFO Created light child device
INFO Starting IAS Zone enrollment
INFO Writing CIE address: <hub-eui>
```

#### When Child Devices Added:
```
INFO Child device added with key: alarm_ep01
INFO Child device added with key: light_ep02
```

#### During Alarm Commands:
```
INFO ALARM HANDLER: Received command: strobe
INFO StartWarning: mode=0x33, duration=60, strobe_duty=75, strobe_level=3
```

#### During Light Commands:
```
INFO SWITCH HANDLER: Received command: on
INFO Light OnOff state: on
INFO LEVEL HANDLER: Set level to 50%
INFO Light level: 50%
```

### ✅ Log Success Indicators
- [ ] "Creating child devices for parent" appears
- [ ] Both children created successfully
- [ ] No Lua errors or exceptions
- [ ] Commands show correct parameters
- [ ] State updates received from device

### ❌ Error Indicators
- Lua runtime errors
- "Failed to create device" messages
- Timeout errors
- "Hub EUI not available" warnings (can retry)

---

## Troubleshooting

### Problem: Only One Device Appears (No Children)

**Cause:** Child devices not created during pairing.

**Solution:**
1. Delete the parent device from SmartThings app
2. Wait 30 seconds
3. Re-pair the device
4. Check logs for "Creating child devices" message
5. Verify `device.parent_device_id == nil` condition is met

---

### Problem: Strobe Still Doesn't Flash Light

**Cause:** May need to test actual strobe parameters or endpoint.

**Debug Steps:**
1. Check logs for strobe command:
   ```
   INFO StartWarning: mode=0x33, duration=60, strobe_duty=75, strobe_level=3
   ```
2. Verify `strobe=STROBE_YES` (value should be 1)
3. Check if light endpoint receives ON command
4. Test "both" command - does it flash?

**If "both" flashes but "strobe" doesn't:**
- The issue may be strobe duty cycle or level
- Can adjust in code: increase duty_cycle to 100, level to VERY_HIGH

---

### Problem: Light Commands Don't Work

**Cause:** Endpoint routing or parent device lookup issue.

**Debug Steps:**
1. Check logs for "SWITCH HANDLER" or "LEVEL HANDLER"
2. Verify parent device is found: `get_parent_device()` returns valid device
3. Check if commands sent to LIGHT_ENDPOINT (0x02)
4. Try controlling light directly from parent device (if visible)

---

### Problem: Battery Shows 0% or Wrong Value

**Cause:** Battery attribute not routing to alarm child.

**Debug Steps:**
1. Send refresh command from alarm device
2. Check logs for "Battery level: XX%"
3. Verify `alarm_child` is found in `battery_percent_handler`
4. Check if parent device shows correct battery level

---

### Problem: Driver Won't Install on Hub

**Cause:** Packaging error or CLI authentication issue.

**Solution:**
1. Verify package created in directory
2. Re-package: `smartthings edge:drivers:package -a`
3. Check YAML syntax in profiles
4. If authentication fails, clear tokens and retry (auth happens automatically)
5. Check CLI version: `smartthings --version`

---

### Problem: Can't Find Driver in SmartThings App

**Cause:** Hub not enrolled in channel or driver not installed.

**Solution:**
1. Check hub enrollment:
   ```bash
   smartthings edge:channels:enrollments
   ```
2. Enroll hub if needed:
   ```bash
   smartthings edge:channels:enroll
   ```
3. Install driver via app (Settings → Driver → Available Drivers)
4. Wait 2-3 minutes after installation before pairing

---

## Rollback Plan

### If V2 Driver Has Issues

**Option 1: Keep Using Original Driver**
- Your two existing sirens are unaffected
- Simply unpair the test device
- Original driver continues working

**Option 2: Revert Test Device to Original Driver**
1. Delete test device from SmartThings
2. Uninstall V2 driver from hub (optional)
3. Re-pair device - it will use original driver

**Option 3: Uninstall V2 Driver Completely**
```bash
smartthings edge:drivers:uninstall <DRIVER_ID> -H <HUB_ID>
```

### Backup Your Original Driver
The original driver is safe at:
```
/Users/satinder/Documents/siren/hive-siren-smartthings-driver/
```

**Never delete this directory!**

---

## Success Criteria Summary

### You've Successfully Deployed V2 When:
- ✅ Package created without errors
- ✅ Driver published to your channel
- ✅ Driver installed on hub
- ✅ Test device paired successfully
- ✅ **Three devices appear**: Parent, Alarm child, Light child
- ✅ Alarm device has all 4 commands (off, siren, strobe, both)
- ✅ Light device has switch and brightness controls
- ✅ **Strobe command produces BOTH audio and flashing light** (THE FIX!)
- ✅ All commands work independently
- ✅ No Lua errors in logs
- ✅ Your two existing sirens still work normally

---

## Next Steps After Successful Testing

### If V2 Works Perfectly:

1. **Keep test device on V2** - use it for a week to ensure stability

2. **Optionally migrate existing devices:**
   - Delete one existing siren from SmartThings
   - Re-pair it → will use V2 driver
   - Test thoroughly
   - Repeat for second siren if satisfied

3. **Publish V2 as stable** (optional):
   - Update version in `config.yml`
   - Re-package and publish
   - Mark as production-ready

### If V2 Has Issues:

1. **Document the issues** in logs
2. **Keep test device** for debugging
3. **Don't migrate existing devices** yet
4. **Review logs** and adjust code
5. **Re-test** after fixes

---

## Quick Reference Commands

```bash
# Package and upload driver (single command)
cd /Users/satinder/Documents/siren/hive-siren-smartthings-driver-v2
smartthings edge:drivers:package -a

# List channels
smartthings edge:channels

# List hubs
smartthings edge:drivers:installed -H

# Install driver on hub
smartthings edge:drivers:install <DRIVER_ID> -H <HUB_ID>

# View logs
smartthings edge:drivers:logcat

# View specific driver logs
smartthings edge:drivers:logcat <DRIVER_ID> --hub-address <HUB_ID>
```

---

## Questions or Issues?

When you come back tomorrow with questions:
1. Have your **driver logs** ready
2. Note which **step** you're on
3. Describe what **happened vs. expected**
4. Include any **error messages**

Good luck with testing! 🚀
