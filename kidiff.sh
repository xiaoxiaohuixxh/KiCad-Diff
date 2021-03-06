#!/usr/bin/env bash

# Takes one or two Fossil ref's as arguments and generates visual diffs between them
# If only one ref specified, generates a diff from that file
# If no refs specified, assumes CURRENT

# TODO Rewrite in Python & improve efficiency.
#       A Python version should be easier to maintain esp the HTML generation.
#       Would be possible to add as a 'plugin' (not sure if that is worthwhile).
# TODO  Add a graticle/grid with grid references.
# TODO Add back code to support alternative SCM (eg git)
# TODO Improve 3-pane layout - possible two side by side and comparison image underneath? id:16
# TODO Improve diff text parser. Currently difficult to diff as modules have multiple
#      entries on different layers - need to identify graphic change with s-expression parser
#      Need to generate a 'tree' and diff changes need to propogate back up tree to id
#      the changed heading category. This could then be used to drive a drop down menu tree.
#      e.g.

#(module Mounting_Holes:MountingHole_5.5mm (layer F.Cu) (tedit 56D1B4CB) (tstamp 598A07F7)
#  (at 112.28 125.28)
#  (descr "Mounting Hole 5.5mm, no annular")
#  (tags "mounting hole 5.5mm no annular")
#  (fp_text reference REF** (at 0 -6.5) (layer F.SilkS)
#    (effects (font (size 1 1) (thickness 0.15)))
#  )
#  (fp_text value MountingHole_5.5mm (at 0 6.5) (layer F.Fab)
#    (effects (font (size 1 1) (thickness 0.15)))
#  )
#  (fp_circle (center 0 0) (end 5.5 0) (layer Cmts.User) (width 0.15))
#  (fp_circle (center 0 0) (end 5.75 0) (layer F.CrtYd) (width 0.05))
#  (pad 1 np_thru_hole circle (at 0 0) (size 5.5 5.5) (drill 5.5) (layers *.Cu *.Mask))
#)

# Changes to the last line need to propogate through to the parent 'Module Mounting_Holes'
# Ideally the aim would be to have 'clicakble' regions.

qual=100
VERSION=2.1

#Default

function usage () {
    cat << EOF
Usage:  kidiff [OPTION] (VERSION) (VERSION2)
    -h  displays this help
    -v  displays version
    -q  quality of image (dpi)

This takes none, one or two Fossil references as arguments and generates visual diffs between them.
If no fossil references are specified, will perform a visual diff between the saved version and CURRENT (HEAD).
If one fossil reference is specified, will performa a visual diff between that and CURRENT (HEAD).
If two fossil references are supplied, will perform a visula diff between them.


(Not yet implemented)
By setting flags for copper, fab, mask and ECO layers, subsets of the diff can be run (faster).

EOF
exit 0
}

while getopts ":hvq" opt; do
    case "$opt" in
    h)  usage
    ;;
    v)  version=$VERSION
        echo "KiDiff : $version"
        exit 0
    ;;
    q)  if ([ $2 -gt 99 ] && [ $2 -lt 601 ]); then
            qual=$2
            shift $((OPTIND-1))
        else
            echo "Quality parameter (q) between 100 and 600 dpi" 1>&2
            exit 1
        fi
    ;;
    \?) echo "KiDiff :  illegal option: $1" 1>&2
        echo "usage: KiDiff [-hvq]"
        exit 1
    ;;
    esac
done

shift $((OPTIND-1))


# TODO Consider removing filename from display format i.e 'filename-F_Cu' becomes 'F_Cu' id:13
# TODO Add command line quality option - Quality is dpi. 100 is fast but low quality id:4
#      600 is very detailed. 300 is a good compromise.
# TODO Consider alternatve generation orders
#      1. svg > png > compare > crop to comparison image > crop source images to match
#      2. svg > recolour
# 2) SVG 'swap'colours would be simplest but although you can colorise the black
#easily, swaping the white for black seems to be problematic - not sure why
#prob something to do with evenodd


# TODO Command line options for selecting which plots id:8

# Remove old plot files

rm -r /tmp/svg

# Set directory for plotting
OUTPUT_DIR="./Plots"
rm -r $OUTPUT_DIR
mkdir $OUTPUT_DIR

# TODO Have added this temporarily to simply remove all the plots prior to generating files. id:12
# Theoretically the script could check if the files have already been generated and then only generate the
# missing files. This would permit multiple diff compares and you could also use an external diff tool like p4merge
# but the disadvantage is that the resoultions have to match. It is also more complicated to script
# Ideally one could request random compares within the web interface and there would
# be 'on the fly' svg/png creation and diff showing.

# Try to keep the web components seperate from the images so that the images could be
# looked at using a graphical diff viewer like p4merge.
# Set directory for web backend

WEB_DIR="web"
mkdir $OUTPUT_DIR/$WEB_DIR
cp ~/Kicad/KiCad-Diff/style.css $OUTPUT_DIR/$WEB_DIR/
# TODO cat >> $OUTPUT_DIR/$WEB_DIR/style.css <<_EOF_ // _EOF_
# TODO Might need to use a more complex strategy  to cope with spaces in filename id:17
# using some varient of 'find . -name "*.pro" -print0 | xargs -0'

#################################
# Colours to substitute per layer
#
# Additionally need to add vias, and internal layers.
# TODO Parse the pcbnew file to determine which layers are active. id:14
# TODO Sort these so that they make sense i.e all B together, all F etc id:5
# Presently these sort alphabetically - thus Cmts/Dwgs/Edge * ECO come between B & F Cu.


F_Cu="#952927"
B_Cu="#359632"
B_Paste="#3DC9C9"
F_Paste="#969696"
F_SilkS="#339697"
B_SilkS="#481649"
B_Mask="#943197"
F_Mask="#943197"
Edge_Cuts="#C9C83B"
Margin="#D357D2"
In1_Cu="#C2C200"
In2_Cu="#C200C2"
Dwgs_User="#0364D3"
Cmts_User="#7AC0F4"
Eco1_User="#008500"
Eco2_User="#C2C200"
B_Fab="#858585"
F_Fab="#C2C200"
B_Adhes="#3545A8"
F_Adhes="#A74AA8"
B_CrtYd="#D3D04B"
F_CrtYd="#A7A7A7"


# Do something like this
#layertable = {}
#numlayers = pcbnew.PCB_LAYER_ID_COUNT
#for i in range(numlayers):
# layertable[board.GetLayerName(i)] = i

# These are the colour definitions for the 'solarised' theme from pcbnew.
#ColorPCBLayer_F.Cu=rgb(221, 47, 44)
#ColorPCBLayer_In3.Cu=rgba(194, 194, 194, 0.800)
#ColorPCBLayer_In4.Cu=rgba(0, 132, 132, 0.800)
#ColorPCBLayer_In5.Cu=rgba(0, 132, 0, 0.800)
#ColorPCBLayer_In6.Cu=rgba(0, 0, 132, 0.800)
#ColorPCBLayer_Margin=rgba(194, 0, 194, 0.800)
#ColorPCBLayer_B.CrtYd=rgba(194, 194, 0, 0.800)
#ColorPCBLayer_F.CrtYd=rgba(132, 132, 132, 0.800)
#ColorTxtFrontEx=rgba(194, 194, 194, 0.800)
#ColorTxtBackEx=rgba(0, 0, 132, 0.800)
#ColorTxtInvisEx=rgba(132, 132, 132, 0.800)
#ColorAnchorEx=rgba(0, 0, 132, 0.800)
#ColorPadBackEx=rgba(0, 132, 0, 0.800)
#ColorPadFrontEx=rgba(132, 132, 132, 0.800)
#ColorViaThruEx=rgba(194, 194, 194, 0.800)
#ColorViaBBlindEx=rgba(132, 132, 0, 0.800)
#ColorViaMicroEx=rgba(0, 132, 132, 0.800)
#ColorNonPlatedEx=rgba(194, 194, 0, 0.800)



#########################################################
# Find the .kicad_pcb files that differ between commits #
#########################################################

# Look at number of arguments provided set different variables based on number of Fossil refs
#############################################################################################

# 0. User provided no Fossil references, compare against last Fossil commit

if [ $# -eq 0 ]; then
  DIFF_1="current"
  DIFF_2=$(fossil info current | grep ^uuid: | sed 's/uuid: *//g'| cut -c 1-6)
  echo $DIFF_2
  CHANGED_KICAD_FILES=$(fossil diff --brief -r  "$DIFF_2" | grep '.kicad_pcb$' | tr -d 'CHANGED[:space:]||ADDED[:space:]')
  if [[ -z "$CHANGED_KICAD_FILES" ]]; then echo "No .kicad_pcb files differ" && exit 0; fi

  # Copy all modified kicad_pcb files to $OUTPUT_DIR/current

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_1"
    cp "$k" $OUTPUT_DIR/current
  done

  # Copy the  Fossil commit kicad_pcb file to $OUTPUT_DIR/commit uuid

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_2"
    echo "Copying $DIFF_2:$k to $OUTPUT_DIR/$DIFF_2/"
    fossil cat $k -r $DIFF_2 > "$OUTPUT_DIR/$DIFF_2/$(basename $k)"
  done


  # 1. User supplied one Fossil reference to compare against current files

  elif [ $# -eq 1 ]; then
  DIFF_1="current"
  DIFF_2="$1"
  CHANGED_KICAD_FILES=$(fossil diff --brief -r  "$DIFF_2" | grep '.kicad_pcb$' | tr -d 'CHANGED[:space:]||ADDED[:space:]')
  if [[ -z "$CHANGED_KICAD_FILES" ]]; then echo "No .kicad_pcb files differ" && exit 0; fi

  # Copy all modified kicad_file to $OUTPUT_DIR/current

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_1"
    cp "$k" $OUTPUT_DIR/current
    fossil info $DIFF_1 > "$OUTPUT_DIR/current/info.txt"
  done

  # Copy the specified Fossil commit kicad_file to $OUTPUT_DIR/$(Fossil ref)

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_2"
    echo "Copying $DIFF_2:$k to $OUTPUT_DIR/$DIFF_2/$k"
    fossil cat $k -r $DIFF_2  > "$OUTPUT_DIR/$DIFF_2/$(basename $k)"
    fossil info $DIFF_2 > "$OUTPUT_DIR/$DIFF_2/info.txt"
  done

  # 2. User supplied 2 Fossil references to compare

  elif [ $# -eq 2 ]; then
  DIFF_1="$1"
  DIFF_2="$2"
  CHANGED_KICAD_FILES=$(fossil diff --brief -r "$DIFF_1" --to "$DIFF_2" | grep '.kicad_pcb$' | tr -d 'CHANGED[:space:]||ADDED[:space:]')
  if [[ -z "$CHANGED_KICAD_FILES" ]]; then echo "No .kicad_pcb files differ" && exit 0; fi

  # Copy all modified kicad_file to $OUTPUT_DIR/current

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_1"
    fossil cat $k -r $DIFF_1  > "$OUTPUT_DIR/$DIFF_1/$(basename $k)"
    fossil info $DIFF_1 > "$OUTPUT_DIR/$DIFF_1/info.txt"
  done

  # Copy the specified Fossil commit kicad_file to $OUTPUT_DIR/Fossil uuid

  for k in $CHANGED_KICAD_FILES; do
    mkdir -p "$OUTPUT_DIR/$DIFF_2"
    echo "Copying $DIFF_2:$k to $OUTPUT_DIR/$DIFF_2/$k"
    fossil cat $k -r $DIFF_2 > "$OUTPUT_DIR/$DIFF_2/$(basename $k)"
    fossil info $DIFF_2 > "$OUTPUT_DIR/$DIFF_2/info.txt"
  done

  # 3. User provided too many references

else
  echo "Please only provide 1 or 2 arguments: not $#"
  exit 2
fi

echo "Kicad files saved to:  '$OUTPUT_DIR/$DIFF_1' and '$OUTPUT_DIR/$DIFF_2'"

# Generate svg files from kicad output
######################################
#
# Use the python script 'plot_pcbnew.py' to generate svg files from the two *.kicad_pcb files.
# Files are saved in /tmp/svg/COMMIT_ID
#

for f in $OUTPUT_DIR/$DIFF_1/*.kicad_pcb; do
  mkdir -p /tmp/svg/$DIFF_1
  echo "Converting $f to .svg:  Files will be saved to /tmp/svg"
  /usr/local/bin/plot_pcbnew.py "$f" "/tmp/svg/$DIFF_1"
done

for f in $OUTPUT_DIR/$DIFF_2/*.kicad_pcb; do
  mkdir -p /tmp/svg/$DIFF_2
  echo "Converting $f to .svg: Files will be saved to /tmp/svg"
  /usr/local/bin/plot_pcbnew.py "$f" "/tmp/svg/$DIFF_2"
done

# Convert svg files into png
######################################
#
# Parse the svg files in /tmp/svg/COMMIT_ID using Image Magick.
# The conversion trims the image to the active area using the 'trim' function.
# Fuzz is probably not nescessary (trim measures the corner pixel value and trims
# to the first non-corner coloured pixel. Fuzz allows for minor variation but as this is
# a generated svg, pixels should be white.)
#
# The .png files are created in the output directory.
#
# BUG The crop size can alter if an item is added or removed on the periphery
# should check that both images are the same size. Provided nothing changes
# around the edges this retains focus and detail on the board.
# Alternativly, would need to scan both images and determine the x+y difference and pad.
# may need to pad both top and bottom -

for p in /tmp/svg/$DIFF_1/*.svg; do
  d=$(basename $p)
  echo "Converting $p to .png"
  convert -density $qual -fuzz 1% -trim +repage "$p" "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png"
 # convert -density $qual "$p" "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png"
  convert "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png" -negate "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png"
done

for p in /tmp/svg/$DIFF_2/*.svg; do
  d=$(basename $p)
  echo "Converting $p to .png"
  convert -density $qual -fuzz 1% -trim +repage "$p" "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png"
 # convert -density $qual "$p" "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png"
  convert "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png" -negate "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png"
done


#for p in $OUTPUT_DIR/$DIFF_1/*.png; do
#    d=$(basename $p)
#    img1w=$(identify -ping -format '%w' "$p")
#    img1h=$(identify -ping -format '%h' "$p")
#    img2w=$(identify -ping -format '%w' "$OUTPUT_DIR/$DIFF_2/$d")
#    img2h=$(identify -ping -format '%h' "$OUTPUT_DIR/$DIFF_2/$d")


#if [ "$img1w" == "$img2w" ] && [ "$img1h" == "$img2h" ]
#then echo "$d - MATCH"
#else
#    echo "$d size $img1w x $img1h _"
#    echo "$OUTPUT_DIR/$DIFF_2/$d size $img2w x $img2h"
#fi
#done


# Generate png diffs between DIFF_1 and DIFF_2
##############################################
#
# Originally the intention was to use the ImageMagic 'composite stereo 0' function to identify
# where items have moved but I could not get this to work.
# This flattens the original files to greyscale and they need to be converted
# back to rgb in order to be colourised.

for g in $OUTPUT_DIR/$DIFF_1/*.png; do
  d=$(basename $g)
  y=${d%.png}
  layerName=${y##*-}
  mkdir -p "$OUTPUT_DIR/diff-$DIFF_1-$DIFF_2"
  echo "Generating composite image $OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/$(basename $g)"
  convert '(' $OUTPUT_DIR/$DIFF_2/$(basename $g) -flatten -grayscale Rec709Luminance ')' \
          '(' $OUTPUT_DIR/$DIFF_1/$(basename $g) -flatten -grayscale Rec709Luminance ')' \
          '(' -clone 0-1 -compose darken -composite ')' \
          -channel RGB -combine $OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/$(basename $g)
  convert "$OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/$(basename $g)" -fill ${!layerName} -fuzz 75% -opaque "#ffffff" "$OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/$(basename $g)"
done

# Done in this order so that if the diff image is cropped to a ROI, then the same crop
# can be applied to the source images. This does not work as the python plot crops
# to the ROI

for p in $OUTPUT_DIR/$DIFF_1/*.png; do
  d=$(basename $p)
  y=${d%.png}
  layerName=${y##*-}
  echo "Converting $layerName to .png with colour "${!layerName}
  convert "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png" -define png:color-type=2 "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png"
  convert "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png" -fill ${!layerName} -fuzz 75% -opaque "#ffffff" "$OUTPUT_DIR/$DIFF_1/${d%%.*}.png"
done

for p in $OUTPUT_DIR/$DIFF_2/*.png; do
  d=$(basename $p)
  y=${d%.png}
  layerName=${y##*-}
  echo "Converting $layerName to .png with colour "${!layerName}
  convert "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png" -define png:color-type=2 "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png"
  convert "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png" -fill ${!layerName} -fuzz 75% -opaque "#ffffff" "$OUTPUT_DIR/$DIFF_2/${d%%.*}.png"
done

# Setup web directories for web output
######################################
#
# Remove index.html prior to streaming new data
# TODO Would be neater to put thumbs, tryptych, index and any .css sheet in a 'web' directory id:9
#

if [ -e $OUTPUT_DIR/$WEB_DIR/index.html ]
    then rm $OUTPUT_DIR/$WEB_DIR/index.html
fi

if [ -d thumbs ]
then echo "'thumbs' directory found"
else mkdir $OUTPUT_DIR/$WEB_DIR/thumbs && echo "'thumbs' directory created"
fi

if [ -d tryptych ]
then echo "'tryptych' directory found"
else mkdir $OUTPUT_DIR/$WEB_DIR/tryptych && echo "'tryptych' directory created"
fi

# Stream HTML <head> and <style> to index.html
##############################################
#
# It would make more sense to stream this to $OUTPUT_DIR/web/style.css
# and reuse it in the 'tryptych' section.

DIFF_1_DATE=$(fossil info $DIFF_1 | grep uuid: | awk -F' ' '{ print $3 }')
DIFF_1_TIME=$(fossil info $DIFF_1 | grep uuid: | awk -F' ' '{ print $4 }')
DIFF_2_DATE=$(fossil info $DIFF_2 | grep uuid: | awk -F' ' '{ print $3 }')
DIFF_2_TIME=$(fossil info $DIFF_2 | grep uuid: | awk -F' ' '{ print $4 }')

TITLE=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | grep title | sed 's/(title_block//g' | sed 's/title//g')
DATE=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | grep date | sed 's/(date //g' | sed 's/)//g')
COMPANY=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | grep company | sed 's/(company "//g' | sed 's/")//g')

THICK1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep thickness | sed 's/(thickness //g' | sed 's/)//g')
DRAWINGS1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep drawings | sed 's/(drawings //g' | sed 's/)//g')
TRACKS1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep tracks | sed 's/(tracks //g' | sed 's/)//g')
ZONES1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep zones | sed 's/(zones //g' | sed 's/)//g')
MODULES1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep modules | sed 's/(modules //g' | sed 's/)//g')
NETS1=$(cat $OUTPUT_DIR/$DIFF_1/*.kicad_pcb | head -n 10 | grep nets | sed 's/(nets //g' | sed 's/)//g')

THICK2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep thickness | sed 's/(thickness //g' | sed 's/)//g')
DRAWINGS2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep drawings | sed 's/(drawings //g' | sed 's/)//g')
TRACKS2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep tracks | sed 's/(tracks //g' | sed 's/)//g')
ZONES2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep zones | sed 's/(zones //g' | sed 's/)//g')
MODULES2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep modules | sed 's/(modules //g' | sed 's/)//g')
NETS2=$(cat $OUTPUT_DIR/$DIFF_2/*.kicad_pcb | head -n 10 | grep nets | sed 's/(nets //g' | sed 's/)//g')

#sed 's/(/<td><div class="th">/g' | sed 's/)/<\/td>/g')

cat >> $OUTPUT_DIR/$WEB_DIR/index.html <<HTML
<!DOCTYPE HTML>
<html lang="en">
<head>
<link rel="stylesheet" type="text/css" href="style.css" media="screen" />

</head>

<table style="border-color: #aaaaaa; width: 100%; height: 2px;" border="2px" cellspacing="2px" cellpadding="3px">
<tbody>
<tr>
<td colspan="6" width="256">
<h1>$CHANGED_KICAD_FILES
<h4>$TITLE
<h5>$DATE
<h5>$COMPANY
</td>
</tr>
<tr>
<td width="83">
<div class = "h3"><b>Version</b></div>
</td>
<td width="89">
<div class="h2 green">$DIFF_1</div>
</td>
<td width="89">
<div class="h2 red">$DIFF_2</div>
</td>
<td width="84">
<div class="h3">Thickness (mm)</div>
</td>
<td width="40">
<div class="h2 green">$THICK1 </div>
</td>
<td width="41">
<div class="h2 red">$THICK2 </div>
</td>
</tr>
<tr>
<td width="83">
<div class="h2">Date</div>
</td>
<td width="89">
<div class="h3">$DIFF_1_DATE</div>
</td>
<td width="89">
<div class="h3">$DIFF_2_DATE</div>
</td>
<td width="84">
<div class="h3">Drawings</div>
</td>
<td width="40">
<div class="h2 green">$DRAWINGS1</div>
</td>
<td width="41">
<div class="h2 red">$DRAWINGS2</div>
</td>
</tr>
<tr>
<td width="83">
<div class="h3"><strong>Time</div>
</td>
<td width="89">
<div class="h3">$DIFF_1_TIME</div>
</td>
<td width="89">
<div class="h3">$DIFF_2_TIME</div>
</td>
<td width="84">
<div class="h3">Tracks</div>
</td>
<td width="40">
<div class="h2 green">$TRACKS1</div>
</td>
<td width="41">
<div class="h2 red">$TRACKS2</div>
</td>
</tr>
<tr>
<td colspan="3" rowspan="3" width="261">
</td>
<td width="84">
<div class="h3">Zones</div>
</td>
<td width="40">
<div class="h2 green">$ZONES1</div>
</td>
<td width="41">
<div class="h2 red">$ZONES2</div>
</td>
</tr>
<tr>
<td width="84">
<div class="h3">Modules</div>
</td>
<td width="40">
<div class="h2 green">$MODULES1</div>
</td>
<td width="41">
<div class="h2 red">$MODULES2</div>
</td>
</tr>
<tr>
<td width="84">
<div class="h3">Nets</div>
</td>
<td width="40">
<div class="h2 green">$NETS1</div>
</td>
<td width="41">
<div class="h2 red">$NETS2</div>
</td>
</tr>
</tbody>
</table>

HTML

#cat ThermocoupleLogger.kicad_pcb grep $mod | head -n 10 | sed 's/(/<td><div class="th">/g' | sed 's/)/<\/td>/g'





for g in $OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/*.png; do
# Attempt to force to same size to prevent gaps in page.
#convert $g -resize 300x245 -extent 300x245 -gravity center -background black $OUTPUT_DIR/$WEB_DIR/thumbs/th_$(basename $g)
convert $g -resize 300x245 -background black -gravity center -extent 300x245 $OUTPUT_DIR/$WEB_DIR/thumbs/th_$(basename $g)

#cp  $g ./plots/thumbs/th_$(basename $g)
  route=$g
  file=${route##*/}
  base=${file%.*}
#  dir=$(dirname $g)
#  echo $dir

cat >> $OUTPUT_DIR/$WEB_DIR/index.html <<HTML
<div class="responsive">
  <div class="gallery">
    <a target="_blank" href = tryptych/$(basename $g).html>
      <img src = thumbs/th_$(basename $g) height="200">
    </a>
    <div class="desc">$base</div>
  </div>
</div>
HTML


cat >>$OUTPUT_DIR/$WEB_DIR/tryptych/$(basename $g).html<<HTML
<!DOCTYPE HTML>
<html lang="en">
<head>
<link rel="stylesheet" type="text/css" href="../style.css" media="screen" />
<style>
div.responsive {
   padding: 0 6px;
   float: left;
   width: 49.99%;
}
</style>
</head>

<body>
<h2>$base</h><br>
<div class="responsive">
    <div class="gallery">
        <a target="_blank" href = $(basename $g).html>
            <a href= ../../$DIFF_1/$(basename $g)><img src = ../../$DIFF_1/$(basename $g) width="500"></a>
        </a>
        <div class="desc green">$DIFF_1</div>
    </div>
</div>


<div class="responsive">
  <div class="gallery">
      <a target="_blank" href = $(basename $g).html>
          <a href= ../../$DIFF_2/$(basename $g)> <img src = ../../$DIFF_2/$(basename $g) width="500"></a>
      </a>
      <div class="desc red">$DIFF_2</div>
  </div>
</div>


<div class="responsive">
    <div class="gallery">
        <a target="_blank" href = $OUTPUT_DIR/$(basename $g).html>
            <a href = ../../diff-$DIFF_1-$DIFF_2/$(basename $g) ><img src = ../../diff-$DIFF_1-$DIFF_2/$(basename $g) width="500"></a>
        </a>
        <div class="desc white">Composite</div>
    </div>
</div>
HTML

d=$(basename $g)
y=${d%.png}
layerName=${y##*-}
mod=${layerName//[_]/.}
echo $mod
diff $OUTPUT_DIR/$DIFF_2/*.kicad_pcb $OUTPUT_DIR/$DIFF_1/*.kicad_pcb >> $OUTPUT_DIR/diff-$DIFF_1-$DIFF_2/diff.txt
diff $OUTPUT_DIR/$DIFF_2/*.kicad_pcb $OUTPUT_DIR/$DIFF_1/*.kicad_pcb |  grep $mod | sed 's/>  /<\/div><div class="differences added">/g' | sed 's/<   /<\/div><div class="differences removed">/g' | sed 's/\/n/<\/div>/g' >> $OUTPUT_DIR/$WEB_DIR/tryptych/$(basename $g).html


# grep $mod | grep 'module' | sed 's/>  /<div class="details">/g' | sed 's/<   /<div class="details">/g' | sed 's/))/)<\/div>/g'  >> $OUTPUT_DIR/$WEB_DIR/tryptych/$(basename $g).html
cat >>$OUTPUT_DIR/$WEB_DIR/tryptych/$(basename $g).html<<FOOT
<div class="clearfix"></div>
<div style="padding:6px;">
</div>
FOOT
done

cat >>$OUTPUT_DIR/$WEB_DIR/index.html<<FOOT
<div class="clearfix"></div>
<div style="padding:6px;">
</div>
FOOT

echo "HTML created and written to index.html"
open $OUTPUT_DIR/$WEB_DIR/index.html
