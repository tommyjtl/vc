# `vc`

A handy `bash` function for video conversion using `ffmpeg`, without the need to figure out complex arguments.

## Install

1. Install [`ffmpeg`](https://www.ffmpeg.org).
2. Locate you `bash` profile, it can be either `.bashrc` or `.bash_profile`.
3. Place the entire `vc` function inside.
4. `source` your profile to make it valid, or restart your `bash` session.

## Usages

The `vc` command is composed of three parameters read from the terminal: `action`, `param`, and `file`. There are 10 types of actions at the moment, and for each action, we may need to supply a parameter.

| Action  | Param      | Description                    | Example                       |
|---------|-----------|---------------------------------|-------------------------------|
| `convert` | format    | Convert video to a new format   | `vc convert mp4 /path/to/video.avi` |
| `vol`     | multiplier| Adjust audio volume by a multiplier factor           | `vc vol 2.0 /path/to/video.mp4` |
| `resize`  | scale     | Scale video dimensions by a multiplier factor | `vc resize 0.5 /path/to/video.mp4` |
| `mute`    | -         | Remove audio from video         | `vc mute - /path/to/video.mp4` |
| `capture` | seconds   | Extract a frame at a specific time in seconds | `vc capture 90 /path/to/video.mp4` |
| `fps`     | framerate | Change frames per second        | `vc fps 30 /path/to/video.mp4` |
| `clip`    | HH:MM:SS-HH:MM:SS | Cut a segment from the video | `vc clip 00:01:23-00:02:45 /path/to/video.mp4` |
| `crop`    | x:y-w:h   | Crop video to a specific region | `vc crop 100:50-1280:720 /path/to/video.mp4` |
| `speed`   | factor    | Change playback speed by a multiplier factor           | `vc speed 2 /path/to/video.mp4` |
| `tosdr`   | -         | Convert HDR video to SDR using a fixed profile | `vc tosdr - /path/to/video.mp4` |