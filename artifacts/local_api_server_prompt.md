# Prompt: Create a Local Mock API Server for SyncCompanion Telemetry

## Task Description

Create a simple HTTP server that runs on a local network to receive telemetry data from the SyncCompanion mobile app. The server should listen for incoming POST requests and print the received data to the terminal for debugging purposes.

## Requirements

1. **Language**: Use Python (Flask or FastAPI) or Node.js (Express) - whichever you're most comfortable with.

2. **Endpoint**: Create a single endpoint that accepts POST requests:
   ```
   POST /api/v1/{device_token}/telemetry
   ```
   - `{device_token}` is a path parameter (can be any string, just print it)

3. **Request Format**: The app sends JSON data in this format:
   ```json
   {
     "ts": 1736714707000,
     "values": {
       "event_type": "sync_session",
       "duration_seconds": 300,
       "start_time": "2025-01-12T19:45:07.000Z"
     }
   }
   ```

4. **Event Types**: The app currently sends these event types:
   - `sync_session` - When a device sync session ends (includes duration and start time)
   - `mission_completed` - When a mission is completed (includes mission_id and mission_title)
   - `minigame_played` - When a minigame is finished (includes game_id, score, and play_time_seconds)

5. **Output**: For each request, print to terminal:
   - Timestamp
   - Device token from URL
   - Full JSON payload (pretty-printed)
   - Separator line for readability

6. **Response**: Return HTTP 200 OK for successful receipt

7. **Network Configuration**:
   - Listen on `0.0.0.0` so it's accessible from other devices on the network
   - Default port: `8080`
   - Print the server URL on startup (e.g., "Server running at http://192.168.1.100:8080")

## Example Output

When the server receives a request, it should print something like:

```
================================================================================
[2025-01-12 19:45:07] Received telemetry from device: MY_DEVICE_TOKEN

{
  "ts": 1736714707000,
  "values": {
    "event_type": "sync_session",
    "duration_seconds": 300,
    "start_time": "2025-01-12T19:45:07.000Z"
  }
}
================================================================================
```

## Testing

To test the server, you can use curl:

```bash
curl -X POST http://localhost:8080/api/v1/test-token/telemetry \
  -H "Content-Type: application/json" \
  -d '{"ts": 1736714707000, "values": {"event_type": "test", "message": "hello"}}'
```

## Bonus Features (Optional)

- Add CORS headers to allow browser testing
- Add a simple GET endpoint at `/` that returns server status
- Log requests to a file as well as terminal
- Add command-line arguments for port configuration
