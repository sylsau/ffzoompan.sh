#!/bin/bash
[[ $DEBUG ]] && set -o nounset
set -o pipefail -o errexit -o errtrace
trap 'echo -e "${FMT_BOLD}ERROR${FMT_OFF}: at $FUNCNAME:$LINENO"' ERR

readonly PROGNAME="$( basename $0 )"

RES=

FFMPEG="${FFMPEG:-ffmpeg}"
INFILE=
OUTFILE=/tmp/ffzoompan-out.mp4
DURATION=20
FRAMERATE=24
CRF=12
ZOOMMAX=2
OUTSIZE="1080x1920"
FF_OPTS=


# $1 = command to test (string)
fn_need_cmd() {
    if ! command -v "$1" > /dev/null 2>&1
        then
            fn_say "need '$1' (command not found)"
            exit 255
    fi
}
# $1 = file to test (string)
fn_is_img() {
    RES=1
    file --mime --brief "$1" | grep "image/" 1>/dev/null || RES=0
}
# $1 = message (string)
fn_say() {
    echo -e "$PROGNAME: $1"
}

fn_help() {
    cat << EOF
$PROGNAME v20230303
    Takes an image or a video and creates a video with a zoom effect into the center of the picture.

REQUIREMENTS
    ffmpeg, file, bc

USAGE
    $PROGNAME -i INPUT_FILE [-o OUTPUT_FILE -t DURATION -r FRAMERATE -q CRF -z MAX_ZOOM -s SIZE -a FF_OPTS]

OPTIONS AND ARGUMENTS
    INPUT_FILE      path to input file
    OUTPUT_FILE     path to output file [default: $OUTFILE]
    DURATION        duration of the output video (in seconds) [default: $DURATION]
    FRAMERATE       framerate of the output video (fps) [default: $FRAMERATE]
    CRF             quality of the output video (constant rate factor) [default: $CRF]
    MAX_ZOOM        zoom value at the end of output video (eg. 2 => x2) [default: $ZOOMMAX]
    SIZE            size of output video (WIDTHxHEIGHT) [default: $OUTSIZE]
    FF_OPTS         other ffmpeg options to pass to the command

EXAMPLE
        $ $PROGNAME -i myvid.avi -o finalvid.mp4 -q 15 -t 5 -z 1.5 -r 30 -s 1974x2554
        $ $PROGNAME -i pic.jpg   -o newvid.mp4   -q 15 -t 5 -z 1.5 -r 30 -s 1974x2554 -a "-pix_fmt yuv420p"

AUTHOR
    Written by Sylvain Saubier (<http://sylsau.com>)

REPORTING BUGS
    Mail at: <feedback@sylsau.com>
EOF
}


fn_need_cmd "ffmpeg"
fn_need_cmd "file"
fn_need_cmd "bc"

if test -z "$*"; then
    fn_help
    exit 10
else
    # Individually check provided args
    while test -n "$1" ; do
        case $1 in
            "--help"|"-h")
                fn_help
                exit
                ;;
            "-i")
                INFILE="$2"
                shift
                ;;
            "-o")
                OUTFILE="$2"
                shift
                ;;
            "-q")
                CRF="$2"
                shift
                ;;
            "-r")
                FRAMERATE="$2"
                shift
                ;;
            "-t")
                DURATION="$2"
                shift
                ;;
            "-z")
                ZOOMMAX="$2"
                shift
                ;;
            "-s")
                OUTSIZE="$2"
                shift
                ;;
            "-a")
                FF_OPTS="$2"
                shift
                ;;
            "--debug")
                FFMPEG="echo $FFMPEG"
                ;;
            *)
                fn_help
                exit 20
                ;;
        esac	# --- end of case ---
        # Delete $1
        shift
    done
fi

if [[ -z "$INFILE" ]]; then
    fn_say "need an input file ! ($PROGNAME -i [...])"
    exit 30
fi

LENGTH=$( echo "$DURATION * 100" | bc )

# NB: the filter "scale=..." upscales the video before zooming, otherwise we get bad results
fn_is_img "$INFILE"
if [[ "$RES" = "1" ]]; then
    $FFMPEG -framerate 25 -loop 1 -i "$INFILE" -vf "scale=(iw*$ZOOMMAX*2):(ih*$ZOOMMAX*2), 
        zoompan=z='min(pzoom+($ZOOMMAX-1)/$LENGTH,$ZOOMMAX)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':fps=25:s=$OUTSIZE" \
        -t $DURATION -r $FRAMERATE -crf:v $CRF $FF_OPTS -y "$OUTFILE"
else
    $FFMPEG                       -i "$INFILE" -vf "scale=(iw*$ZOOMMAX*2):(ih*$ZOOMMAX*2), 
        zoompan=z='min(pzoom+($ZOOMMAX-1)/$LENGTH,$ZOOMMAX)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':fps=25:s=$OUTSIZE"  \
        -t $DURATION -r $FRAMERATE -crf:v $CRF -c:a copy $FF_OPTS -y "$OUTFILE"
fi

fn_say "output to $OUTFILE"
fn_say "all done!"
