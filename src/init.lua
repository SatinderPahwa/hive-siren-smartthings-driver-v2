-- Hive Siren SmartThings Edge Driver
-- PRD-Compliant Version with Corrected Syntax

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local clusters = require "st.zigbee.zcl.clusters"
local defaults = require "st.zigbee.defaults"
local log = require "log"

-- Import clusters using recommended approach
local IASWD = clusters.IASWD
local IASZone = clusters.IASZone
local OnOff = clusters.OnOff
local Level = clusters.Level
local PowerConfiguration = clusters.PowerConfiguration
local Basic = clusters.Basic

-- PRD-specified endpoints
local SIREN_ENDPOINT = 0x01  -- EP 0x01: IAS Warning Device (0x0403)
local LIGHT_ENDPOINT = 0x02  -- EP 0x02: Dimmable Light (0x0101)

-- IAS WD Constants (PRD-Compliant)
local WARNING_MODE_STOP = 0x00
local WARNING_MODE_BURGLAR = 0x01
local WARNING_MODE_FIRE = 0x02
local WARNING_MODE_EMERGENCY = 0x03
local WARNING_MODE_POLICE_PANIC = 0x04
local WARNING_MODE_FIRE_PANIC = 0x05
local WARNING_MODE_EMERGENCY_PANIC = 0x06
local STROBE_NO = 0
local STROBE_YES = 1
local SIREN_LEVEL_LOW = 0
local SIREN_LEVEL_MEDIUM = 1
local SIREN_LEVEL_HIGH = 2
local SIREN_LEVEL_VERY_HIGH = 3
local DEFAULT_WARNING_DURATION = 60

---
-- CAPABILITY HANDLERS
---

local function handle_alarm(driver, device, command)
  log.info(string.format("ALARM HANDLER: Received command: %s", command.command))
  
  local warning_mode = WARNING_MODE_BURGLAR
  local strobe = STROBE_NO
  local siren_level = SIREN_LEVEL_HIGH
  local duration = DEFAULT_WARNING_DURATION

  if command.command == "off" then
    warning_mode = WARNING_MODE_STOP
    siren_level = SIREN_LEVEL_LOW
    duration = 0
    strobe = STROBE_NO
    
    -- Also turn off flood light when stopping alarm
    device:send(OnOff.server.commands.Off(device):to_endpoint(LIGHT_ENDPOINT))
  elseif command.command == "siren" then
    -- Siren only - EMERGENCY with strobe YES produces full siren (tested working)
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_YES
    siren_level = SIREN_LEVEL_LOW
  elseif command.command == "strobe" then
    -- Strobe only - EMERGENCY with no strobe produces beep (visual/entry alert)
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_NO
    siren_level = SIREN_LEVEL_HIGH
  elseif command.command == "both" then
    -- Both siren and strobe - Try different strobe parameters
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_YES
    siren_level = SIREN_LEVEL_LOW
  end

  -- For both mode, try reading the LED config first, then set both siren and light
  if command.command == "both" then
    log.info("Both mode: trying siren + manual light control")
    
    -- First turn on the flood light for visual effect
    device:send(OnOff.server.commands.On(device):to_endpoint(LIGHT_ENDPOINT))
    
    -- Then send siren command (will use current warning_mode/siren_level settings)
    -- This keeps the audio part working
  end
  
  -- Build IASWD command parameters according to PRD specifications
  local warning_info = (warning_mode & 0x0F) | ((strobe & 0x03) << 4) | ((siren_level & 0x03) << 6)
  
  -- For both mode, try different strobe parameters
  if command.command == "both" then
    -- Try maximum strobe duty cycle and different level
    strobe_duty_cycle = 100  -- Max duty cycle
    strobe_level = SIREN_LEVEL_VERY_HIGH  -- Max strobe level
    log.info("Both mode: using max strobe duty=100, level=VERY_HIGH")
  else
    strobe_duty_cycle = (strobe == STROBE_YES) and 50 or 0
    strobe_level = (strobe == STROBE_YES) and SIREN_LEVEL_HIGH or 0
  end
  
  log.info(string.format("PRD-Compliant StartWarning: mode=0x%02X, duration=%d, strobe_duty=%d, strobe_level=%d", 
    warning_info, duration, strobe_duty_cycle, strobe_level))
  
  -- Send command to siren endpoint
  device:send(IASWD.server.commands.StartWarning(device, warning_info, duration, strobe_duty_cycle, strobe_level):to_endpoint(SIREN_ENDPOINT))
  
  -- For both mode, also turn on flood light for visual effect
  if command.command == "both" then
    device.thread:call_with_delay(0.2, function()
      device:send(OnOff.server.commands.On(device):to_endpoint(LIGHT_ENDPOINT))
      log.info("Flood light turned on for both mode")
    end)
  end
  
  -- Log command sent (removed sounder state read as attribute doesn't exist)
  log.info("StartWarning command sent to device")
  
  device:emit_component_event(
    device.profile.components.main, 
    capabilities.alarm.alarm(command.command)
  )
end

local function handle_switch(driver, device, command)
  log.info(string.format("SWITCH HANDLER: Received command: %s for component: %s", 
    command.command, command.component))
  
  -- Main component switch controls the light for easy access
  local is_main = (command.component == "main")
  
  local zigbee_command = (command.command == "on") and 
    OnOff.server.commands.On(device) or OnOff.server.commands.Off(device)
  
  -- Always send to light endpoint
  device:send(zigbee_command:to_endpoint(LIGHT_ENDPOINT))
  
  -- Schedule a read to verify the command was received
  device.thread:call_with_delay(1, function()
    device:send(OnOff.attributes.OnOff:read(device):to_endpoint(LIGHT_ENDPOINT))
  end)
  
  -- Emit events for both main and light components if main was triggered
  if is_main then
    device:emit_component_event(
      device.profile.components.main, 
      capabilities.switch.switch(command.command)
    )
  end
  
  -- Always update light component
  device:emit_component_event(
    device.profile.components.light, 
    capabilities.switch.switch(command.command)
  )
end

local function handle_level(driver, device, command)
  local level = command.args.level
  log.info(string.format("LEVEL HANDLER: Set level to %d%% for component: %s", 
    level, command.component))
  
  -- Convert percentage (0-100) to Zigbee level (0-254)
  local zigbee_level = math.floor(level * 2.54)
  
  -- Send level command with transition time of 1 second
  device:send(Level.server.commands.MoveToLevelWithOnOff(device, zigbee_level, 10):to_endpoint(LIGHT_ENDPOINT))
  
  -- Schedule a read to verify the command was received
  device.thread:call_with_delay(2, function()
    device:send(Level.attributes.CurrentLevel:read(device):to_endpoint(LIGHT_ENDPOINT))
  end)
  
  -- Emit event for the correct component
  local component = command.component and device.profile.components[command.component] or device.profile.components.light
  device:emit_component_event(
    component, 
    capabilities.switchLevel.level(level)
  )
end

---
-- LIFECYCLE HANDLERS
---

local function device_added(driver, device)
  log.info("Hive Siren added: " .. device.id)
  
  -- Initialize device state for both components
  device:emit_component_event(device.profile.components.main, capabilities.switch.switch("off"))
  device:emit_component_event(device.profile.components.main, capabilities.alarm.alarm("off"))
  device:emit_component_event(device.profile.components.main, capabilities.battery.battery(100))
  
  if device.profile.components.light then
    device:emit_component_event(device.profile.components.light, capabilities.switch.switch("off"))
    device:emit_component_event(device.profile.components.light, capabilities.switchLevel.level(100))
  end
  
  -- Read basic device info
  device:send(Basic.attributes.ManufacturerName:read(device):to_endpoint(SIREN_ENDPOINT))
  device:send(Basic.attributes.ModelIdentifier:read(device):to_endpoint(SIREN_ENDPOINT))
end

local function device_init(driver, device)
  log.info("Hive Siren initialized: " .. device.id)
  
  -- Perform IAS Zone enrollment sequence
  log.info("Starting IAS Zone enrollment")
  
  -- First read the zone type and status
  device:send(IASZone.attributes.ZoneType:read(device):to_endpoint(SIREN_ENDPOINT))
  device:send(IASZone.attributes.ZoneStatus:read(device):to_endpoint(SIREN_ENDPOINT))
  
  -- Get hub EUI from driver environment
  local hub_zigbee_eui = (driver.environment_info and driver.environment_info.hub_zigbee_eui) or nil
  
  if not hub_zigbee_eui then
    -- Wait for driver startup state to be available
    log.info("Hub EUI not immediately available, will retry after startup")
    device.thread:call_with_delay(5, function()
      local delayed_hub_eui = (driver.environment_info and driver.environment_info.hub_zigbee_eui) or nil
      if delayed_hub_eui then
        log.info("Delayed CIE address write: " .. tostring(delayed_hub_eui))
        device:send(IASZone.attributes.IASCIEAddress:write(device, delayed_hub_eui):to_endpoint(SIREN_ENDPOINT))
        
        -- Send enrollment response after CIE address write
        device.thread:call_with_delay(2, function()
          log.info("Sending delayed Zone Enroll Response")
          device:send(IASZone.server.commands.ZoneEnrollResponse(device, 0x00, 0x01):to_endpoint(SIREN_ENDPOINT))
        end)
      else
        log.error("Hub EUI still not available - siren functionality will be limited")
      end
    end)
  end
  
  if hub_zigbee_eui then
    log.info("Writing CIE address: " .. tostring(hub_zigbee_eui))
    device:send(IASZone.attributes.IASCIEAddress:write(device, hub_zigbee_eui):to_endpoint(SIREN_ENDPOINT))
    
    -- Trigger enrollment after setting CIE address
    device.thread:call_with_delay(2, function()
      log.info("Sending Zone Enroll Request")
      -- Send zone enroll response to complete enrollment
      device:send(IASZone.server.commands.ZoneEnrollResponse(device, 0x00, 0x01):to_endpoint(SIREN_ENDPOINT))
    end)
  else
    log.warn("Hub EUI not available for IAS Zone enrollment - device may not function properly")
  end
  
  -- Schedule periodic refresh to keep device alive
  device.thread:call_on_schedule(
    300,  -- Every 5 minutes
    function()
      log.debug("Sending keep-alive refresh")
      -- Read light state to maintain connection
      device:send(OnOff.attributes.OnOff:read(device):to_endpoint(LIGHT_ENDPOINT))
    end,
    "keep_alive_timer"
  )
end

local function do_configure(driver, device)
  log.info("Configuring Hive Siren: " .. device.id)
  
  -- Configure cluster reporting per PRD specifications
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(device, 30, 21600, 1):to_endpoint(SIREN_ENDPOINT))
  device:send(OnOff.attributes.OnOff:configure_reporting(device, 0, 300, 1):to_endpoint(LIGHT_ENDPOINT))
  device:send(Level.attributes.CurrentLevel:configure_reporting(device, 1, 3600, 1):to_endpoint(LIGHT_ENDPOINT))
  
  -- Read initial states
  device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(device):to_endpoint(SIREN_ENDPOINT))
  device:send(OnOff.attributes.OnOff:read(device):to_endpoint(LIGHT_ENDPOINT))
  device:send(Level.attributes.CurrentLevel:read(device):to_endpoint(LIGHT_ENDPOINT))
end

-- IAS Zone enrollment request handler
local function ias_zone_enroll_request_handler(driver, device, zone_type, manufacturer)
  log.info(string.format("IAS Zone enrollment request received - Zone Type: %s, Manufacturer: %s", 
    tostring(zone_type), tostring(manufacturer)))
  
  -- Send enrollment response with success status
  device:send(IASZone.server.commands.ZoneEnrollResponse(device, 0x00, 0x01):to_endpoint(SIREN_ENDPOINT))
  log.info("Sent IAS Zone enrollment response")
end

-- IAS Zone status change handler
local function ias_zone_status_change_handler(driver, device, zone_status)
  log.info(string.format("IAS Zone status change: 0x%04X", zone_status.value))
  
  -- Update device status based on zone status bits
  local is_alarm1 = (zone_status.value & 0x0001) ~= 0
  local is_alarm2 = (zone_status.value & 0x0002) ~= 0
  local is_tamper = (zone_status.value & 0x0004) ~= 0
  local is_battery_low = (zone_status.value & 0x0008) ~= 0
  
  if is_battery_low then
    device:emit_component_event(device.profile.components.main, 
      capabilities.battery.battery(10))  -- Low battery warning
  end
end

-- Battery reporting handler
local function battery_percent_handler(driver, device, value)
  if value and value.value then
    -- Clamp battery percentage to valid range (0-100)
    local battery_percent = math.max(0, math.min(100, value.value))
    log.info(string.format("Battery level: %d%% (raw: %d)", battery_percent, value.value))
    device:emit_component_event(device.profile.components.main, 
      capabilities.battery.battery(battery_percent))
  end
end

-- OnOff attribute handler for light endpoint
local function onoff_attr_handler(driver, device, value, zb_rx)
  if zb_rx.address_header.src_endpoint.value == LIGHT_ENDPOINT then
    log.info(string.format("Light OnOff state: %s", value.value and "on" or "off"))
    local state = value.value and "on" or "off"
    
    -- Update both main and light components
    device:emit_component_event(
      device.profile.components.main,
      capabilities.switch.switch(state)
    )
    device:emit_component_event(
      device.profile.components.light,
      capabilities.switch.switch(state)
    )
  end
end

-- Level attribute handler for light endpoint  
local function level_attr_handler(driver, device, value, zb_rx)
  if zb_rx.address_header.src_endpoint.value == LIGHT_ENDPOINT then
    local level_percent = math.floor(value.value / 2.54)
    log.info(string.format("Light level: %d%%", level_percent))
    device:emit_component_event(
      device.profile.components.light,
      capabilities.switchLevel.level(level_percent)
    )
  end
end

-- Handler for manufacturer-specific attribute reports from Basic cluster
local function basic_mfg_report_handler(driver, device, zb_rx)
  -- The reports come as ReportAttribute messages from Basic cluster with mfg_code 0x1168
  if zb_rx.body and zb_rx.body.zcl_body and zb_rx.body.zcl_body.attr_records then
    for _, record in ipairs(zb_rx.body.zcl_body.attr_records) do
      if record.attr_id.value == 0x4028 then
        -- Sounder state attribute
        local is_sounding = record.data.value == 1
        log.info(string.format("Sounder state (0x4028): %s", 
          is_sounding and "SOUNDING" or "SILENT"))
      elseif record.attr_id.value == 0x4025 then
        -- Device status
        log.info(string.format("Device status (0x4025): 0x%02X", record.data.value))
      elseif record.attr_id.value == 0x4026 then
        -- Network status
        log.info(string.format("Network status (0x4026): %s", 
          record.data.value == 1 and "JOINED" or "NO_NETWORK"))
      elseif record.attr_id.value == 0x4022 then
        -- RF Jamming status
        log.info(string.format("RF Jamming (0x4022): %s", 
          record.data.value == 1 and "DETECTED" or "Clear"))
      end
    end
  end
end

---
-- DRIVER DEFINITION
---

local hive_siren_driver = {
  supported_capabilities = {
    capabilities.alarm,
    capabilities.switch,
    capabilities.switchLevel,
    capabilities.battery,
    capabilities.refresh
  },
  
  capability_handlers = {
    [capabilities.alarm.ID] = {
      [capabilities.alarm.commands.off.NAME] = handle_alarm,
      [capabilities.alarm.commands.siren.NAME] = handle_alarm,
      [capabilities.alarm.commands.strobe.NAME] = handle_alarm,
      [capabilities.alarm.commands.both.NAME] = handle_alarm
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_switch,
      [capabilities.switch.commands.off.NAME] = handle_switch
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = handle_level
    },
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = function(driver, device)
        device:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(device):to_endpoint(SIREN_ENDPOINT))
        device:send(OnOff.attributes.OnOff:read(device):to_endpoint(LIGHT_ENDPOINT))
        device:send(Level.attributes.CurrentLevel:read(device):to_endpoint(LIGHT_ENDPOINT))
      end
    }
  },
  
  zigbee_handlers = {
    global = {
      [Basic.ID] = {
        [0x0A] = basic_mfg_report_handler  -- ReportAttribute command (0x0A)
      }
    },
    cluster = {
      [IASZone.ID] = {
        [IASZone.client.commands.ZoneStatusChangeNotification.ID] = ias_zone_status_change_handler,
        [IASZone.client.commands.ZoneEnrollRequest.ID] = ias_zone_enroll_request_handler
      }
    },
    attr = {
      [PowerConfiguration.ID] = {
        [PowerConfiguration.attributes.BatteryPercentageRemaining.ID] = battery_percent_handler
      },
      [OnOff.ID] = {
        [OnOff.attributes.OnOff.ID] = onoff_attr_handler
      },
      [Level.ID] = {
        [Level.attributes.CurrentLevel.ID] = level_attr_handler
      }
    }
  },
  
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    doConfigure = do_configure
  }
}

-- Register default handlers
defaults.register_for_default_handlers(hive_siren_driver, hive_siren_driver.supported_capabilities)

-- Create and run driver
local driver = ZigbeeDriver("hive-siren", hive_siren_driver)
driver:run()