# Kodi IP Control Driver for Control4

A Control4 driver for Kodi media players with full playback control and two-way communication.

## Features

### Playback Control
- Play, Pause, Stop
- Skip Forward/Backward (configurable interval)
- Scan Forward/Backward (2x speed)
- Full navigation (Up, Down, Left, Right, Enter, Back)
- Playback info display

### Two-Way Communication
- Real-time player state monitoring (Playing/Paused/Stopped)
- Live video resolution and aspect ratio
- Media type detection (video/audio)
- Configurable polling interval

### System Monitoring
- CPU usage
- Memory usage
- System temperature
- Uptime
- Kodi version
- Screen saver status

### Advanced Features
- Configurable Program Buttons (Red, Green, Yellow, Blue):
  - Show Codec Info
  - Show OSD
  - Show Player Process Info
  - Toggle Subtitles
  - Next Subtitle
  - Next Audio Track
  - Screenshot
- Debug mode with detailed logging
- HTTP timeout handling (5 second timeout)
- Batched JSON-RPC requests for efficiency

## Requirements
- Control4 OS 2.10 or later
- Kodi 18+ with JSON-RPC API enabled (enabled by default)
- Network connectivity between Control4 system and Kodi device

## Installation
1. Download the latest release
2. In Control4 Composer Pro:
   - Navigate to **System Design** view
   - Right-click on project tree → **Add Driver**
   - Select **Browse** → Choose the driver file
   - Right-click the new driver → **Properties**
   - Configure IP address and port (default: 8080)

## Configuration

### Basic Setup
- **IP Address**: IP address of your Kodi device
- **Port**: JSON-RPC port (default: 8080)
- **Skip Interval**: Seconds to skip forward/backward (default: 30)

### Polling
- **Enable Polling**: ON/OFF (default: ON)
- **Poll Interval**: 1-60 seconds (default: 60)

### Program Buttons
Configure the Red, Green, Yellow, and Blue buttons to trigger various actions or set to None to disable.

### Debug Mode
Enable detailed logging in Composer Pro's Lua Output window for troubleshooting.

## Connections
In Composer Pro, bind the Kodi driver to your room's video and audio endpoints as needed.

## Performance
- HTTP timeout: 5 seconds (3 second connection timeout)
- Batched JSON-RPC requests: 2 HTTP requests per poll cycle
- Recommended polling interval: 30-60 seconds for optimal performance

## Troubleshooting

### Driver doesn't connect
- Verify Kodi's IP address and port
- Ensure JSON-RPC is enabled in Kodi (Settings → Services → Control)
- Check firewall settings on Kodi device
- Enable Debug Mode and check Lua Output

### Commands not working
- Verify driver is bound to room's media endpoints
- Review Lua Output for error messages


## License
MIT License

---

This is a community-developed driver and is not officially supported by Control4 or Kodi.
