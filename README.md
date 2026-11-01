# Cam helper scripts

Helpers for a Sony a6000 connected to a Mac via an Elgato Cam Link 4K (HDMI).
Requires `ffmpeg` (`brew install ffmpeg`).

| Script                         | What it does                                                                                                                                         | Run                                               |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `sony-a6000-test-recording.sh` | Records a 5s test clip from the Cam Link so you can check the picture. Saves to `recordings/sony-a6000-test-<timestamp>.mp4` unless you give a path. | `./sony-a6000-test-recording.sh [output_file]`    |
| `sony-a6000-watchdog.sh`       | Runs continuously and reports when the Cam Link or video stream appears/disappears. Logs to `/tmp/sony-a6000-watchdog.log`. Stop with Ctrl+C.        | `./sony-a6000-watchdog.sh [seconds]` (default 10) |
