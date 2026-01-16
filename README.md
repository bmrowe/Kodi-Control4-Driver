# Kodi IP Control Driver for Control4

A Control4 driver for Kodi media players using WebSocket communication for real-time playback control and status monitoring.

## Features

### Real-Time Communication
- WebSocket connection to Kodi JSON-RPC API (port 9090)
- Instant notification of playback events (no polling required)
- Automatic reconnection if connection is lost

### Playback Control
- Play, Pause, Stop
- Skip Forward/Backward with configurable interval
- Scan Forward/Backward (fast forward/rewind)
- Full navigation (Up, Down, Left, Right, Enter, Back, Menu, Info)

### Live Status Display
- Player state (Playing/Paused/Stopped/Fast Forward/Rewind)
- Media type (video/audio)
- Real-time media information:
  - Video resolution (e.g., 3840x1600)
  - Aspect ratio (e.g., 2.40)
  - Video codec and HDR status (e.g., hevc HDR10)
  - Audio codec, channels, and language (e.g., eac3_ddp_atmos 6ch eng)

### Playback Directionals Mode
Two modes for directional button behavior during playback:
- **PM4K Mode** (default): Standard navigation for Popcorn Machine 4K and similar add-ons
- **Kodi Mode**: Directionals become seek controls during playback
  - Up/Down = Big Step Forward/Back (10 minutes)
  - Left/Right = Step Forward/Back (10 seconds)
  - Enter = Play/Pause toggle

### Configurable Program Buttons
Map Red, Green, Yellow, and Blue buttons to various Kodi functions:
- Show Codec Info
- Show OSD
- Show Player Process Info
- Toggle Subtitles
- Next Subtitle/Audio Track
- Screenshot

## Requirements
- Control4 OS 2.10 or later
- Kodi 18+ (Leia or newer)
- Network connectivity between Control4 system and Kodi device

## Installation
1. Download the `.c4z` driver file
2. In Control4 Composer Pro:
   - **System Design** view → Right-click project tree → **Add Driver**
   - Select **Browse** → Choose the `.c4z` file
   - Configure driver properties (right-click → **Properties**)
3. Set the **IP Address** of your Kodi device

## Configuration

### Driver Properties

| Property | Description | Default |
|----------|-------------|---------|
| **IP Address** | IP address of your Kodi device | (required) |
| **Skip Interval** | Seconds to skip forward/backward | 30 |
| **Playback Directionals** | Navigation mode during playback | PM4K |
| **Program Buttons** | Actions for Red/Green/Yellow/Blue buttons | No Operation |
| **Debug Mode** | Enable detailed logging | OFF |

### Skip Interval Behavior
- **< 30 seconds**: Small step (typically a few seconds)
- **30-599 seconds**: Step (typically 10 seconds)
- **≥ 600 seconds**: Big step (typically 10 minutes)

### Kodi Configuration
Ensure JSON-RPC is enabled (default):
1. Kodi: **Settings → Services → Control**
2. Enable **Allow remote control via HTTP**
3. Enable **Allow remote control from applications on other systems**

## Connections
In Composer Pro's **Connections** view, connect the driver's **Media Player** proxy (binding 5001) to your room's audio/video endpoints.

## Troubleshooting

### Driver doesn't connect
- Verify Kodi's IP address in driver properties
- Ensure Kodi is running and network accessible
- Check firewall settings (port 9090)
- Enable **Debug Mode** and check Lua Output window

### Commands work but no status updates
- Verify JSON-RPC remote control is enabled in Kodi
- Restart both Kodi and the Control4 driver
- Check Debug Mode logs for "NOTIFICATION:" messages

### Media Info shows "N/A"
- Media info only populates during active video playback
- Some add-ons may not provide all metadata

### Navigation doesn't work correctly during playback
- For Popcorn Machine 4K: Use **PM4K** mode
- For standard Kodi: Try **Kodi** mode

## License
MIT License

---

**Note**: This is a community-developed driver and is not officially supported by Control4 or Kodi.
