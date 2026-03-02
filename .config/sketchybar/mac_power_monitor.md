# mac_power_monitor Output Documentation

## Command
```bash
mac_power_monitor
```

## Output Format (JSON)

### When Charging
```json
{
  "system_watts": 70.588,
  "cpu_watts": 5.79,
  "gpu_watts": 0.24,
  "ane_watts": 0.0,
  "other_watts": 64.558,
  "battery": {
    "charge_percent": 88.0,
    "is_charging": true,
    "health_percent": 97.319,
    "cycle_count": 92,
    "temperature_c": 30.75,
    "adapter_watts": 100,
    "charging_watts": 45.053
  }
}
```

### When Discharging
```json
{
  "system_watts": 20.37,
  "cpu_watts": 5.67,
  "gpu_watts": 0.232,
  "ane_watts": 0.0,
  "other_watts": 14.468,
  "battery": {
    "charge_percent": 88.0,
    "is_charging": false,
    "health_percent": 97.319,
    "cycle_count": 92,
    "temperature_c": 30.65,
    "adapter_watts": null,
    "charging_watts": -28.896
  }
}
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `system_watts` | float | Total system power consumption in watts |
| `cpu_watts` | float | CPU power consumption in watts |
| `gpu_watts` | float | GPU power consumption in watts |
| `ane_watts` | float | Apple Neural Engine power consumption in watts |
| `other_watts` | float | Other components power consumption in watts |
| `battery.charge_percent` | float | Current battery charge percentage |
| `battery.is_charging` | bool | Whether the battery is currently charging |
| `battery.health_percent` | float | Battery health as a percentage |
| `battery.cycle_count` | int | Number of charge cycles |
| `battery.temperature_c` | float | Battery temperature in Celsius |
| `battery.adapter_watts` | float/null | Adapter wattage when connected, null when disconnected |
| `battery.charging_watts` | float | Positive when charging, negative when discharging (power flow rate) |
