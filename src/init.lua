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
-- CHILD DEVICE ROUTING
-- These must be declared BEFORE the capability handlers that use them
---

-- Find child device by endpoint
local function find_child_by_endpoint(parent, endpoint)
  if endpoint == SIREN_ENDPOINT then
    return parent:get_child_by_parent_assigned_key("alarm_ep01")
  elseif endpoint == LIGHT_ENDPOINT then
    return parent:get_child_by_parent_assigned_key("light_ep02")
  end
  return nil
end

-- Get endpoint from device (works for parent and child)
local function get_device_endpoint(device)
  if device.parent_device_id then
    -- This is a child device
    local child_key = device:get_parent_assigned_child_key()
    if child_key == "alarm_ep01" then
      return SIREN_ENDPOINT
    elseif child_key == "light_ep02" then
      return LIGHT_ENDPOINT
    end
  end
  return nil
end

-- Returns true if device is an EDGE_CHILD (virtual child), false for physical Zigbee device.
-- Physical Zigbee devices have parent = hub (not managed by this driver, so get_device_info returns nil).
-- EDGE_CHILD devices have parent = the physical siren (managed by this driver, returns non-nil).
local function is_edge_child(driver, device)
  if device.parent_device_id == nil then return false end
  local parent = driver:get_device_info(device.parent_device_id)
  return parent ~= nil
end

-- Get parent device (returns self if already parent)
local function get_parent_device(driver, device)
  if is_edge_child(driver, device) then
    return driver:get_device_info(device.parent_device_id)
  end
  return device
end

---
-- CAPABILITY HANDLERS
---

local function handle_alarm(driver, device, command)
  log.info(string.format("ALARM HANDLER: Received command: %s", command.command))

  -- Get parent device to send Zigbee commands
  local parent = get_parent_device(driver, device)

  local warning_mode = WARNING_MODE_BURGLAR
  local strobe = STROBE_NO
  local siren_level = SIREN_LEVEL_HIGH
  local duration = DEFAULT_WARNING_DURATION

  if command.command == "off" then
    warning_mode = WARNING_MODE_STOP
    siren_level = SIREN_LEVEL_LOW
    duration = 0
    strobe = STROBE_NO

    -- Turn off both siren and light
    parent:send(OnOff.server.commands.Off(parent):to_endpoint(LIGHT_ENDPOINT))

  elseif command.command == "siren" then
    -- Audio only - emergency mode with no strobe
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_NO
    siren_level = SIREN_LEVEL_HIGH

  elseif command.command == "strobe" then
    -- Loud siren: EMERGENCY + strobe=YES + level=LOW (confirmed working)
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_YES
    siren_level = SIREN_LEVEL_LOW

    -- Also activate the light endpoint for visual effect
    parent:send(OnOff.server.commands.On(parent):to_endpoint(LIGHT_ENDPOINT))

  elseif command.command == "both" then
    -- Full alarm - strobe=YES + level=LOW produces loud siren on Hive hardware
    warning_mode = WARNING_MODE_EMERGENCY
    strobe = STROBE_YES
    siren_level = SIREN_LEVEL_LOW

    -- Turn on the flood light for visual effect
    parent:send(OnOff.server.commands.On(parent):to_endpoint(LIGHT_ENDPOINT))
  end

  -- Build IASWD command parameters
  local warning_info = (warning_mode & 0x0F) | ((strobe & 0x03) << 4) | ((siren_level & 0x03) << 6)

  -- Set strobe parameters based on command
  local strobe_duty_cycle = (strobe == STROBE_YES) and 50 or 0
  local strobe_level = (strobe == STROBE_YES) and SIREN_LEVEL_HIGH or 0

  -- For "both" mode, strobe=YES + level=LOW produces loud siren on Hive hardware
  if command.command == "both" then
    strobe_duty_cycle = 50
    strobe_level = SIREN_LEVEL_HIGH
  elseif command.command == "strobe" then
    -- For strobe mode, use strong visual effect
    strobe_duty_cycle = 75
    strobe_level = SIREN_LEVEL_VERY_HIGH
  end

  log.info(string.format("StartWarning: mode=0x%02X, duration=%d, strobe_duty=%d, strobe_level=%d",
    warning_info, duration, strobe_duty_cycle, strobe_level))

  -- Send command to siren endpoint via parent
  parent:send(IASWD.server.commands.StartWarning(parent, warning_info, duration, strobe_duty_cycle, strobe_level):to_endpoint(SIREN_ENDPOINT))

  -- Emit event to the alarm child device (or main if called on parent)
  device:emit_component_event(
    device.profile.components.main,
    capabilities.alarm.alarm(command.command)
  )
end

local function handle_switch(driver, device, command)
  log.info(string.format("SWITCH HANDLER: Received command: %s", command.command))

  -- Get parent device to send Zigbee commands
  local parent = get_parent_device(driver, device)

  local zigbee_command = (command.command == "on") and
    OnOff.server.commands.On(parent) or OnOff.server.commands.Off(parent)

  -- Send to light endpoint
  parent:send(zigbee_command:to_endpoint(LIGHT_ENDPOINT))

  -- Schedule a read to verify
  device.thread:call_with_delay(1, function()
    parent:send(OnOff.attributes.OnOff:read(parent):to_endpoint(LIGHT_ENDPOINT))
  end)

  -- Emit event to the calling device (light child)
  device:emit_component_event(
    device.profile.components.main,
    capabilities.switch.switch(command.command)
  )
end

local function handle_level(driver, device, command)
  local level = command.args.level
  log.info(string.format("LEVEL HANDLER: Set level to %d%%", level))

  -- Get parent device to send Zigbee commands
  local parent = get_parent_device(driver, device)

  -- Convert percentage to Zigbee level
  local zigbee_level = math.floor(level * 2.54)

  -- Send level command
  parent:send(Level.server.commands.MoveToLevelWithOnOff(parent, zigbee_level, 10):to_endpoint(LIGHT_ENDPOINT))

  -- Schedule a read to verify
  device.thread:call_with_delay(2, function()
    parent:send(Level.attributes.CurrentLevel:read(parent):to_endpoint(LIGHT_ENDPOINT))
  end)

  -- Emit event to the calling device (light child)
  device:emit_component_event(
    device.profile.components.main,
    capabilities.switchLevel.level(level)
  )
end

---
-- LIFECYCLE HANDLERS
---

local function device_added(driver, device)
  log.info("Hive Siren added: " .. device.id)

  -- Only create children if this is the physical Zigbee device (not an EDGE_CHILD)
  if not is_edge_child(driver, device) then
    log.info("Creating child devices for parent: " .. device.id)
    create_child_devices_if_needed(driver, device)

    -- Initialize parent device state (minimal)
    device:emit_component_event(device.profile.components.main, capabilities.battery.battery(100))
  else
    -- This is an EDGE_CHILD device being added.
    -- Guard: if parent is also an EDGE_CHILD, this is a cascade device — delete it.
    local parent = driver:get_device_info(device.parent_device_id)
    if parent and is_edge_child(driver, parent) then
      log.error("Cascade child detected in added, deleting: " .. device.id)
      device:delete()
      return
    end

    local child_key = device.parent_assigned_child_key
    log.info("Child device added with key: " .. tostring(child_key))

    if child_key == "alarm_ep01" then
      -- Initialize alarm child
      device:emit_component_event(device.profile.components.main, capabilities.alarm.alarm("off"))
      device:emit_component_event(device.profile.components.main, capabilities.battery.battery(100))
    elseif child_key == "light_ep02" then
      -- Initialize light child
      device:emit_component_event(device.profile.components.main, capabilities.switch.switch("off"))
      device:emit_component_event(device.profile.components.main, capabilities.switchLevel.level(100))
    end
  end

  -- Read basic device info (only for physical Zigbee device)
  if not is_edge_child(driver, device) then
    device:send(Basic.attributes.ManufacturerName:read(device):to_endpoint(SIREN_ENDPOINT))
    device:send(Basic.attributes.ModelIdentifier:read(device):to_endpoint(SIREN_ENDPOINT))
  end
end

local function create_child_devices_if_needed(driver, device)
  -- Check if children already exist (idempotent - safe to call multiple times)
  local alarm_child = device:get_child_by_parent_assigned_key("alarm_ep01")
  local light_child = device:get_child_by_parent_assigned_key("light_ep02")

  if alarm_child == nil then
    log.info("Creating alarm child device for: " .. device.id)
    driver:try_create_device({
      type = "EDGE_CHILD",
      parent_device_id = device.id,
      parent_assigned_child_key = "alarm_ep01",
      label = device.label .. " - Alarm",
      profile = "hive-siren-alarm",
      manufacturer = "Hive",
      model = "SIREN001-Alarm",
      vendor_provided_label = "Hive Siren Alarm"
    })
  else
    log.info("Alarm child already exists, skipping creation")
  end

  if light_child == nil then
    log.info("Creating light child device for: " .. device.id)
    driver:try_create_device({
      type = "EDGE_CHILD",
      parent_device_id = device.id,
      parent_assigned_child_key = "light_ep02",
      label = device.label .. " - Light",
      profile = "hive-siren-light",
      manufacturer = "Hive",
      model = "SIREN001-Light",
      vendor_provided_label = "Hive Siren Light"
    })
  else
    log.info("Light child already exists, skipping creation")
  end
end

local function device_init(driver, device)
  -- Handle EDGE_CHILD devices
  if is_edge_child(driver, device) then
    -- Check if this is a cascade child (child of a child) — delete it
    local parent = driver:get_device_info(device.parent_device_id)
    if parent and is_edge_child(driver, parent) then
      log.error("Cascade child detected in init, deleting: " .. device.id)
      device:delete()
      return
    end
    log.info("Child device initialized: " .. device.id .. " (skipping Zigbee init)")
    return
  end

  log.info("Hive Siren initialized: " .. device.id)

  -- Create child devices if they don't exist yet.
  -- This handles driver-switch assignments where device_added is NOT called.
  create_child_devices_if_needed(driver, device)
  
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
  -- Skip Zigbee configuration for EDGE_CHILD devices
  if is_edge_child(driver, device) then
    log.info("Child device configure: " .. device.id .. " (skipping Zigbee config)")
    return
  end

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

---
-- ZIGBEE EVENT HANDLERS
---

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

  local is_alarm1 = (zone_status.value & 0x0001) ~= 0
  local is_alarm2 = (zone_status.value & 0x0002) ~= 0
  local is_tamper = (zone_status.value & 0x0004) ~= 0
  local is_battery_low = (zone_status.value & 0x0008) ~= 0

  if is_battery_low then
    -- Route to alarm child device
    local alarm_child = device:get_child_by_parent_assigned_key("alarm_ep01")
    if alarm_child then
      alarm_child:emit_component_event(alarm_child.profile.components.main,
        capabilities.battery.battery(10))
    else
      device:emit_component_event(device.profile.components.main,
        capabilities.battery.battery(10))
    end
  end
end

-- Battery reporting handler
local function battery_percent_handler(driver, device, value)
  if value and value.value then
    local battery_percent = math.max(0, math.min(100, value.value))
    log.info(string.format("Battery level: %d%%", battery_percent))

    -- Route to alarm child device only
    local alarm_child = device:get_child_by_parent_assigned_key("alarm_ep01")
    if alarm_child then
      alarm_child:emit_component_event(alarm_child.profile.components.main,
        capabilities.battery.battery(battery_percent))
    else
      -- Fallback to parent if child not found
      device:emit_component_event(device.profile.components.main,
        capabilities.battery.battery(battery_percent))
    end
  end
end

-- OnOff attribute handler for light endpoint
local function onoff_attr_handler(driver, device, value, zb_rx)
  if zb_rx.address_header.src_endpoint.value == LIGHT_ENDPOINT then
    log.info(string.format("Light OnOff state: %s", value.value and "on" or "off"))
    local state = value.value and "on" or "off"

    -- Route to light child device
    local light_child = device:get_child_by_parent_assigned_key("light_ep02")
    if light_child then
      light_child:emit_component_event(light_child.profile.components.main,
        capabilities.switch.switch(state))
    else
      -- Fallback to parent if child not found
      device:emit_component_event(device.profile.components.main,
        capabilities.switch.switch(state))
    end
  end
end

-- Level attribute handler for light endpoint  
local function level_attr_handler(driver, device, value, zb_rx)
  if zb_rx.address_header.src_endpoint.value == LIGHT_ENDPOINT then
    local level_percent = math.floor(value.value / 2.54)
    log.info(string.format("Light level: %d%%", level_percent))

    -- Route to light child device
    local light_child = device:get_child_by_parent_assigned_key("light_ep02")
    if light_child then
      light_child:emit_component_event(light_child.profile.components.main,
        capabilities.switchLevel.level(level_percent))
    else
      -- Fallback to parent if child not found
      device:emit_component_event(device.profile.components.main,
        capabilities.switchLevel.level(level_percent))
    end
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
        local parent = get_parent_device(driver, device)

        -- Refresh battery (for alarm child)
        parent:send(PowerConfiguration.attributes.BatteryPercentageRemaining:read(parent):to_endpoint(SIREN_ENDPOINT))

        -- Refresh light state (for light child)
        parent:send(OnOff.attributes.OnOff:read(parent):to_endpoint(LIGHT_ENDPOINT))
        parent:send(Level.attributes.CurrentLevel:read(parent):to_endpoint(LIGHT_ENDPOINT))
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
