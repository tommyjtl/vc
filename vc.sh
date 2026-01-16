# => ACTION     PARAM                  FILE
# --|----------|----------------------|------------------|
# vc convert    mp4                    /path/to/video.avi
# vc vol        2.0                    /path/to/video.mp4
# vc resize     0.5                    /path/to/video.mp4
# vc mute       -                      /path/to/video.mp4
# vc capture    90                     /path/to/video.mp4
# vc clip       00:01:23-00:02:45      /path/to/video.mp4
# vc crop       100:50-1280:720        /path/to/video.mp4
# vc speed      2                      /path/to/video.mp4
# vc tosdr      -                      /path/to/video.mp4
# vc fps        30                     /path/to/video.mp4

vc() {
    if [[ $# -ne 3 ]]; then
        cat << 'EOF'
Usage: vc <action> <param> <file>

Available actions:

  convert    mp4                    Convert video to a new format
  vol        2.0                    Adjust audio volume by a multiplier factor
  resize     0.5                    Scale video dimensions by a multiplier factor
  mute       -                      Remove audio from video
  capture    90                     Extract a frame at a specific time in seconds
  clip       00:01:23-00:02:45      Cut a segment from the video
  crop       100:50-1280:720        Crop video to a specific region
  speed      2                      Change playback speed
  tosdr      -                      Convert HDR video to SDR
  fps        30                     Change frames per second

EOF
        return 1
    fi

    # Check if ffmpeg is installed
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg is not installed. Please install it first."
        return 1
    fi

    action=$1
    param=$2
    file=$3

    # Obtain the file extension and base name without the extension
    extension="${file##*.}"
    filename="${file%.*}"

    # Helper: HH:MM:SS -> seconds (handles leading zeros)
    hms_to_sec() {
        IFS=':' read -r h m s <<< "$1"
        # Validate numeric components
        if ! [[ "$h" =~ ^[0-9]{2}$ && "$m" =~ ^[0-9]{2}$ && "$s" =~ ^[0-9]{2}$ ]]; then
            echo ""
            return 1
        fi
        echo $((10#$h*3600 + 10#$m*60 + 10#$s))
    }

    # -c:v h264_videotoolbox means uses GPU to convert

    case $action in
        convert)
            if [ -z "$param" ]; then
                echo "Please specify the target video format"
                return 1
            fi
            # Construct the output file name by changing its extension
            converted_file="${filename}_converted.$param"
            echo "Converting $file to format $param..."
            ffmpeg -i "$file" -c:v h264_videotoolbox "$converted_file"
            if [ $? -eq 0 ]; then
                echo "Converted file created: $converted_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        vol)
            if [ -z "$param" ]; then
                echo "Please specify the volume parameter (e.g., 1.5 for 150%)"
                return 1
            fi
            # Ensure the output file uses the correct same extension
            volume_changed_file="${filename}_vol_changed.$extension"
            echo "Changing volume of $file by $param times..."
            ffmpeg -i "$file" -c:v h264_videotoolbox -af "volume=$param" "$volume_changed_file"
            if [ $? -eq 0 ]; then
                echo "Volume adjusted file created: $volume_changed_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        resize)
            if [ -z "$param" ]; then
                echo "Please specify the resize ratio (e.g., 0.5 for 50% reduction)"
                return 1
            fi
            # Validation to ensure input is a number which will be critical for ffmpeg
            if ! [[ "$param" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                echo "The resize ratio must be a number."
                return 1
            fi
            # Resize the video while maintaining the aspect ratio
            resized_file="${filename}_resized.$extension"
            echo "Resizing $file by a factor of $param..."
            ffmpeg -i "$file" -vf "scale=iw*$param:ih*$param" "$resized_file"
            if [ $? -eq 0 ]; then
                echo "Resized file created: $resized_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        mute)
            muted_file="${filename}_muted.$extension"
            echo "Muting $file..."
            ffmpeg -i "$file" -c:v h264_videotoolbox -an "$muted_file"
            if [ $? -eq 0 ]; then
                echo "Muted file created: $muted_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        capture)
            if ! [[ "$param" =~ ^[0-9]+$ ]]; then
                echo "Please provide the capture time in seconds, as an integer."
                return 1
            fi
            capture_file="${filename}_frame_at_${param}s.jpg"
            echo "Capturing frame at ${param} seconds..."
            ffmpeg -ss "$param" -i "$file" -frames:v 1 -q:v 2 "$capture_file"
            if [ $? -eq 0 ]; then
                echo "Captured frame saved as: $capture_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        clip)
            # param must be HH:MM:SS-HH:MM:SS
            if ! [[ "$param" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}-[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
                echo "Please provide time range as HH:MM:SS-HH:MM:SS (e.g., 00:01:23-00:02:45)."
                return 1
            fi

            IFS='-' read -r start_ts end_ts <<< "$param"

            start_sec=$(hms_to_sec "$start_ts") || { echo "Invalid start time."; return 1; }
            end_sec=$(hms_to_sec "$end_ts") || { echo "Invalid end time."; return 1; }

            if (( end_sec <= start_sec )); then
                echo "End time must be greater than start time."
                return 1
            fi

            duration=$(( end_sec - start_sec ))
            # Build an easy-to-read output name, replacing ":" with ""
            safe_start="${start_ts//:/}"
            safe_end="${end_ts//:/}"
            clip_file="${filename}_clip_${safe_start}-${safe_end}.$extension"

            echo "Clipping $file from $start_ts to $end_ts (duration ${duration}s)..."
            # Fast, keyframe-aligned cut (no re-encode)
            ffmpeg -ss "$start_ts" -i "$file" -t "$duration" -c copy "$clip_file"

            # For frame-accurate cuts, comment the line above and use the line below instead:
            # ffmpeg -ss "$start_ts" -i "$file" -t "$duration" -c:v h264_videotoolbox -c:a aac "$clip_file"

            if [ $? -eq 0 ]; then
                echo "Clipped file created: $clip_file"
            else
                echo "Failed to create clip."
                return 1
            fi
            ;;
            
        crop)
            # Expect param as "x:y-w:h"
            if ! [[ "$param" =~ ^[0-9]+:[0-9]+-[0-9]+:[0-9]+$ ]]; then
                echo "Please provide the cropping zone as starting_x:starting_y-width:height (e.g., 100:50-1280:720)."
                return 1
            fi

            IFS='-' read -r start_xy size_wh <<< "$param"
            IFS=':' read -r x y <<< "$start_xy"
            IFS=':' read -r w h <<< "$size_wh"

            # Validate integers (non-negative)
            for val_name in x y w h; do
                val=${!val_name}
                if ! [[ "$val" =~ ^[0-9]+$ ]]; then
                    echo "All crop values must be non-negative integers. Got $val_name='$val'."
                    return 1
                fi
            done

            # Ensure width/height are > 0
            if (( w == 0 || h == 0 )); then
                echo "Crop width and height must be greater than 0. Got width=$w height=$h."
                return 1
            fi

            # Get source video dimensions
            dims=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$file")
            if [ -z "$dims" ]; then
                echo "Unable to read video dimensions (is ffprobe installed and the file valid?)."
                return 1
            fi
            IFS='x' read -r vid_w vid_h <<< "$dims"

            # Bounds checks
            if (( x < 0 || y < 0 )); then
                echo "starting_x and starting_y must be >= 0. Got x=$x y=$y."
                return 1
            fi
            if (( x >= vid_w || y >= vid_h )); then
                echo "Starting point is outside the video frame ($vid_wx$vid_h). Got x=$x y=$y."
                return 1
            fi
            if (( x + w > vid_w || y + h > vid_h )); then
                max_w=$(( vid_w - x ))
                max_h=$(( vid_h - y ))
                echo "Cropping area exceeds video bounds ($vid_wx$vid_h)."
                echo "Max allowed width from x=$x is $max_w; max allowed height from y=$y is $max_h."
                echo "You provided width=$w height=$h."
                return 1
            fi

            # Output filename
            crop_file="${filename}_crop_${x}x${y}-${w}x${h}.$extension"

            echo "Cropping $file to ${w}x${h} at offset ${x},${y} (source ${vid_w}x${vid_h})..."
            # Cropping requires re-encode; use GPU encoder where available, copy audio.
            ffmpeg -i "$file" -filter:v "crop=${w}:${h}:${x}:${y}" -c:v h264_videotoolbox -c:a copy "$crop_file"

            if [ $? -eq 0 ]; then
                echo "Cropped file created: $crop_file"
            else
                echo "Failed to crop video."
                return 1
            fi
            ;;
            
        speed)
            if [ -z "$param" ]; then
                echo "Please specify a speed factor (e.g., 2 for 2x, 0.5 for half speed)."
                return 1
            fi

            # Validate positive number
            if ! [[ "$param" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$param <= 0" | bc -l) )); then
                echo "Speed factor must be a positive number. Got: $param"
                return 1
            fi

            speed_file="${filename}_${param}x.$extension"
            echo "Changing playback speed of $file to ${param}x..."

            # Video: setpts = 1/speed * PTS
            v_filter="setpts=$(echo "scale=6; 1/$param" | bc)*PTS"

            # Audio: atempo supports only 0.5–2.0 per filter → chain if needed
            atempo_chain=""
            remaining="$param"

            while (( $(echo "$remaining > 2.0" | bc -l) )); do
                atempo_chain="${atempo_chain}atempo=2.0,"
                remaining=$(echo "scale=6; $remaining / 2.0" | bc)
            done

            atempo_chain="${atempo_chain}atempo=$remaining"

            ffmpeg -i "$file" \
                -filter_complex "[0:v]$v_filter[v];[0:a]$atempo_chain[a]" \
                -map "[v]" -map "[a]" \
                -c:v h264_videotoolbox -c:a aac \
                "$speed_file"

            if [ $? -eq 0 ]; then
                echo "Speed-adjusted file created: $speed_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        tosdr)
            # param is not used, can be any value (commonly '-')
            # Extension for output file: .mp4 (as in the `ffmpeg` example)
            # adjusting `npl` to change the brightness level
            #   -vf "...zscale...": Applies the HDR → SDR tone-mapping
            #   tonemap=hable: Uses a filmic tone mapping curve; you can try reinhard, mobius, or bt.2390 for different looks
            #   -c:v libx264: Encodes SDR video using H.264 (widespread compatibility)
            #   -crf 18: High quality output (lower = better quality; try 20–23 if file size is a concern)
            #   -preset slow: Improves compression efficiency (can use medium or faster if you're in a hurry)
            #   -c:a aac -b:a 192k: Converts or copies audio into AAC format at good quality
            tosdr_file="${filename}_SDR.mp4"
            echo "Converting $file to SDR using HDR to SDR tonemapping and x264..."
            ffmpeg -i "$file" \
                -vf "zscale=t=linear:npl=150,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" \
                -c:v libx264 -crf 14 -preset medium -c:a aac -b:a 192k "$tosdr_file"
            if [ $? -eq 0 ]; then
                echo "SDR tonemapped file created: $tosdr_file"
            else
                echo "Process not finished"
                return 1
            fi
            ;;

        fps)
            if [ -z "$param" ]; then
                echo "Please specify the target FPS (e.g., 24, 25, 30, 60)"
                return 1
            fi
            # Validate that param is a positive number
            if ! [[ "$param" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$param <= 0" | bc -l) )); then
                echo "FPS must be a positive number. Got: $param"
                return 1
            fi

            # Get the current FPS of the video
            current_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file")
            if [ -z "$current_fps" ]; then
                echo "Unable to read video FPS (is ffprobe installed and the file valid?)."
                return 1
            fi

            # Convert fraction to decimal for comparison (e.g., "30000/1001" -> 29.97)
            if [[ "$current_fps" =~ / ]]; then
                current_fps_decimal=$(echo "scale=2; $current_fps" | bc)
            else
                current_fps_decimal=$current_fps
            fi

            # Compare FPS values (allowing small floating point differences)
            fps_diff=$(echo "scale=2; $current_fps_decimal - $param" | bc | tr -d '-')
            if (( $(echo "$fps_diff < 0.1" | bc -l) )); then
                echo "Video is already at ${current_fps_decimal} FPS (target: ${param}). No processing needed."
                return 0
            fi

            fps_file="${filename}_${param}fps.$extension"
            echo "Changing FPS of $file from ${current_fps_decimal} to ${param}..."
            ffmpeg -i "$file" -filter:v "fps=fps=$param" -c:v h264_videotoolbox -c:a copy "$fps_file"
            
            if [ $? -eq 0 ]; then
                echo "FPS-adjusted file created: $fps_file"
            else
                echo "Failed to change FPS."
                return 1
            fi
            ;;

        *)
            echo "Unsupported action: $action"
            return 1
            ;;
    esac
}