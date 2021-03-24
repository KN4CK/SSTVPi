#!/bin/bash
#
# This is a program to do a SSTV beacon transmission for W8DC Field Day
#
# This is a decent modification of Don Hoover WS4E script for W4CN Field Day
#   that was originally found at https://gist.github.com/nixfu/5736852 (dead link)
#
#   More links related to Don Hoover's project:
#   https://gist.github.com/ws4e/20b475195b95e6e7a0333d0911d991f4
#   http://ws4e.blogspot.com/2013/06/i-wanted-to-do-something-different-for.html
#
# 06/2013 - Don Hoover WS4E
# 05/2020 - Greg Stoike KN4CK
#
# Requires imagemagick, python, pysstv
#

############################
### Variable declaration ###
############################

# Program directory
export sstvdir=/home/pi/sstv
cd $sstvdir

# We will trigger the PTT relay using GPIO23
# We will listen for SQL using GPIO24
ptt_pin=23
sql_pin=24

# set the GPIO for input/output
gpio -g mode $ptt_pin output
gpio -g mode $sql_pin input

############################
### Create an SSTV image ###
############################

# take a picture using the webcam
echo -e "Picture:\n\tTaking picture.."
fswebcam --quiet --resolution 640x480 --skip 2 --frames 2 --banner-colour "#000000" --line-colour "#FF000000" --no-shadow --title "KN4CK" --png 9 --save sstvimage.png

# add an 8px border to the top and bottom to make it the proper resolution (640x498) for PD120
# uses imagemagick (dependency)
echo -e "\tAdding border.."
convert sstvimage.png -bordercolor black -border x8 sstvimage.png

# turn image into wav file
# uses python and pysstv (dependency)
echo -e "\tConverting image into wav file.."
python -m pysstv --mode PD120 sstvimage.png sstvsound.wav

################################
### Check if the SQL is open ###
################################

# Check SQL for 15 seconds, if SQL is open, delay and then retry
echo -e "\nChecking for sound on the radio.."

for try in {1..4}
do
    sql_status_1=""
    sql_status_15=""
    for i in {1..15}
    do
        sql_status_1=$(gpio -g read $sql_pin)
        if [[ "$sql_status_1" -eq "1" ]];
        then
            sql_status_15=1
        fi
        sleep 1
    done

    if [[ "$sql_status_15" -eq "1" ]];
    then
        echo -e "\tSomething heard on the radio, waiting to transmit.. ($try/4)"
    fi

    if [[ "$sql_status_15" -eq "0" ]];
    then
        echo -e "\tNothing heard on the radio, getting ready to transmit.."
        break
    fi

    if [[ "$try" -eq "4" ]];
    then
        echo -e "\tToo much heard on the radio, max tries have been hit. Exiting!"
        exit
    fi

    sleep 10
done

######################
### Play wav files ###
######################

echo -e "\nTransmitting:"

# key the radio
echo -e "\tKeying the radio"
gpio -g write $ptt_pin 1

#aplay intro.wav
echo -e "\tTransmitting into.."
#aplay -q kn4ck.wav
sleep 3

echo -e "\tTransmitting SSTV image.."
aplay -q sstvsound.wav
sleep 2

#aplay ident.wav
echo -e "\tTransmitting end ident."
#aplay -q kn4ck.wav
sleep 1

# unkey the radio
echo -e "\tUnkeying the radio"
gpio -g write $ptt_pin 0
gpio -g write $ptt_pin 0

###########################
### Cleanup loose stuff ###
###########################

echo -e "Cleanup:"

# move sent image to archive
timestamp=$(date +%m-%d-%Y_%H.%M)
echo -e "\tSSTV image $timestamp.png moved to archive"
mv sstvimage.png archive/$timestamp.png

# remove sound file
rm sstvsound.wav

echo -e "\nSSTV completed."
