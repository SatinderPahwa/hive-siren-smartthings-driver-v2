# Hive Siren SmartThings Edge Driver

This is a SmartThings Edge driver for the Hive Siren device that is no longer officially supported by Hive. This driver enables you to control both the siren and the built-in light through SmartThings.

## Features

- **Siren Control**: Turn the siren on/off with different modes
- **Light Control**: Control the built-in strobe light independently
- **Alarm Modes**: Support for siren only, strobe only, or both
- **Battery Monitoring**: Track battery status (if supported by device)

## Prerequisites

Before you begin, you'll need:

1. **Samsung/SmartThings Account**: You need a Samsung account and the SmartThings app
2. **SmartThings Hub**: A SmartThings-compatible hub that supports Zigbee
3. **SmartThings CLI**: Command-line interface for deploying the driver
4. **Developer Mode**: Enable Developer Mode in SmartThings

## Step-by-Step Installation Instructions

### Step 1: Install SmartThings CLI

1. Download the SmartThings CLI from: https://github.com/SmartThingsCommunity/smartthings-cli/releases
2. Choose the version for your operating system (Windows, Mac, or Linux)
3. Install the CLI following the instructions for your OS

For macOS using Homebrew:
```bash
brew install smartthingscommunity/smartthings/smartthings
```

### Step 2: Set Up Developer Mode

1. Open the SmartThings app on your phone
2. Go to **Menu** (≡) → **Settings**
3. Tap on your Samsung account at the top
4. Tap **Developer Mode** and enable it
5. Sign in with your Samsung account if prompted

### Step 3: Create a Channel for Your Driver

1. Open terminal/command prompt
2. Login to SmartThings CLI:
   ```bash
   smartthings edge:channels:create
   ```
3. Follow the prompts to create a new channel (give it a name like "My Custom Drivers")
4. Note down the Channel ID that's created

### Step 4: Package the Driver

1. Navigate to the driver directory:
   ```bash
   cd /Users/lgpahwas/Downloads/siren/hive-siren-driver
   ```

2. Package the driver:
   ```bash
   smartthings edge:drivers:package
   ```
   This creates a `hive-siren.zip` file

### Step 5: Upload the Driver to Your Channel

1. Upload the driver:
   ```bash
   smartthings edge:drivers:publish hive-siren.zip --channel <YOUR_CHANNEL_ID>
   ```
   Replace `<YOUR_CHANNEL_ID>` with the ID from Step 3

### Step 6: Install the Driver on Your Hub

1. List your hubs to get the Hub ID:
   ```bash
   smartthings edge:drivers:installed
   ```

2. Install the driver to your hub:
   ```bash
   smartthings edge:drivers:install <DRIVER_ID> --hub <HUB_ID> --channel <CHANNEL_ID>
   ```

### Step 7: Pair Your Hive Siren

1. **Reset the Hive Siren** (if previously paired):
   - Usually involves holding a reset button for 10 seconds
   - The LED should flash to indicate it's in pairing mode
   - Consult your siren's manual for specific reset instructions

2. **Add Device in SmartThings App**:
   - Open SmartThings app
   - Tap the **+** button
   - Select **Device**
   - Select **Scan for nearby devices** or **Scan QR code**
   - The app should discover your Hive Siren

3. **Complete Setup**:
   - Name your device
   - Assign it to a room
   - The device should appear with Alarm and Switch capabilities

## Using Your Hive Siren

### In the SmartThings App

Once paired, you'll see two main controls:

1. **Alarm Control**:
   - **Off**: Turns off both siren and light
   - **Siren**: Activates sound only
   - **Strobe**: Activates light only
   - **Both**: Activates both sound and light

2. **Switch Control** (for the light):
   - **On**: Turns on the strobe light continuously
   - **Off**: Turns off the light

### Creating Automations

You can create automations in SmartThings to:
- Trigger the siren when motion is detected
- Flash the light when doors open
- Set up security routines
- Create emergency alerts

Example automation:
1. Go to **Automations** tab
2. Tap **+** to create new automation
3. Set trigger (e.g., "Motion detected")
4. Set action (e.g., "Turn on siren")
5. Set duration and other conditions

## Troubleshooting

### Device Not Pairing

1. **Ensure the device is reset**: The LED should be flashing
2. **Check hub compatibility**: Ensure your hub supports Zigbee
3. **Check driver logs**:
   ```bash
   smartthings edge:drivers:logcat <DRIVER_ID> --hub <HUB_ID>
   ```

### Device Paired but Not Responding

1. **Check battery**: Replace if low
2. **Check Zigbee mesh**: Device might be too far from hub
3. **Refresh device**: Use the refresh capability in the app
4. **Re-pair device**: Remove and add again

### Finding Device Information

If the device pairs but shows as "Thing" or wrong type:
1. In SmartThings app, go to device settings
2. Note the **Manufacturer** and **Model** values
3. Update the `fingerprints.yml` file with these values
4. Re-package and re-deploy the driver

## Advanced Configuration

### Modifying Warning Durations

Edit `src/init.lua` and change:
```lua
local DEFAULT_WARNING_DURATION = 30  -- Change to desired seconds
```

### Adding Custom Warning Modes

The driver supports different warning types. You can modify the `handle_custom_warning` function to add more modes.

### Adjusting Sound Levels

Modify the `SIREN_LEVEL_*` constants:
```lua
local SIREN_LEVEL_LOW = 0
local SIREN_LEVEL_MEDIUM = 1
local SIREN_LEVEL_HIGH = 2
local SIREN_LEVEL_VERY_HIGH = 3
```

## Support

For issues or questions:
1. Check the driver logs for errors
2. Ensure your device firmware is compatible
3. Try re-pairing the device
4. Check SmartThings Community forums for similar issues

## Safety Notes

- Test the siren at a low volume first
- Be aware of local noise regulations
- Ensure the siren is mounted securely
- Test regularly to ensure it's working
- Have a way to quickly disable it if needed

## License

This driver is provided as-is for personal use. Use at your own risk.