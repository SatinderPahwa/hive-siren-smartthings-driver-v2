# Hive Siren V2 - Quick Testing Checklist

## Pre-Flight Check
- [ ] Your two existing sirens are working (don't touch them!)
- [ ] Have a test device (new siren OR can reset one)
- [ ] SmartThings CLI installed: `smartthings --version`
- [ ] Authentication will happen automatically on first command

---

## Deployment Steps

### 1. Package and Upload (5 min)
```bash
cd /Users/satinder/Documents/siren/hive-siren-smartthings-driver-v2
smartthings edge:drivers:package -a
```
**✓ Expected:** Driver uploaded and assigned to channel
**📝 SAVE THE DRIVER ID FROM THE OUTPUT!**

### 2. Install on Hub (2 min)
**Via SmartThings App:**
- Menu → Settings → Driver
- Find your channel → Available Drivers
- Install "Hive Siren"
- Wait 1-2 minutes

### 3. Pair Test Device (3 min)
- Reset siren (hold button 10 sec with batteries)
- SmartThings app → Devices → + → Scan nearby
- Add "Hive Siren"

### 4. Verify Children Created (1 min)
**Should see 3 devices:**
- [ ] "Hive Siren" (parent)
- [ ] "Hive Siren - Alarm" (child)
- [ ] "Hive Siren - Light" (child)

---

## Testing Checklist

### Alarm Device Tests
- [ ] **OFF** → Silence + light off
- [ ] **SIREN** → Audio only
- [ ] **STROBE** → Audio + flashing light ⭐ THE FIX!
- [ ] **BOTH** → Max audio + max light
- [ ] Battery level displays

### Light Device Tests
- [ ] **ON** → Light turns on
- [ ] **OFF** → Light turns off
- [ ] **Brightness 25%** → Dims
- [ ] **Brightness 75%** → Brightens
- [ ] **Brightness 100%** → Full bright

### Log Verification
```bash
smartthings edge:drivers:logcat
```
**Look for:**
- [ ] "Creating child devices for parent"
- [ ] "Created alarm child device"
- [ ] "Created light child device"
- [ ] "Child device added with key: alarm_ep01"
- [ ] "Child device added with key: light_ep02"
- [ ] No Lua errors

---

## Success = All Green Checkmarks! ✅

If issues occur, see full TESTING-GUIDE.md for troubleshooting.

---

## Critical Commands Reference

```bash
# Package and upload driver
smartthings edge:drivers:package -a

# View logs
smartthings edge:drivers:logcat

# List what's installed
smartthings edge:drivers:installed -H
```

---

## Rollback if Needed
1. Unpair test device
2. Your existing sirens remain on original driver
3. Can delete V2 driver from hub (Settings → Driver)

**Your existing setup is 100% safe!** ✅
