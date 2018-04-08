#!/bin/bash

AWSCLI=/usr/local/bin/aws
S3BUCKET=ragnar-lonn-org
LOCALDIR=/media/usb1/ragnar

S3LIST=/tmp/s3filelist.$$.tmp
LOCALLIST=/tmp/localfilelist.$$.tmp

# How many files to copy, max, on each execution
MAXCOPY=200
NUMCOPY=0
DUPLICATES=0

echo "Starting `date`"

# Create a list of all files currently in the S3 bucket
${AWSCLI} s3 ls --recursive s3://${S3BUCKET} >$S3LIST
#2017-02-04 21:14:56          5 hej/hopp
#2017-02-04 21:18:36          4 hej/san/sa
#2017-02-05 10:17:42          3 hej/san/saa

# Create a list of all files currently in the local backup folder
find ${LOCALDIR} -type f >${LOCALLIST}
#/media/usb1/ragnar/Amalia/Amalia/pregnancy pictures/untitled folder/IMG_2621.JPG
#/media/usb1/ragnar/Amalia/Amalia/Veckobrev 40.docx

IFS=$'\r\n' GLOBIGNORE='*' command eval 'LOCALFILES=($(cat '${LOCALLIST}'))'
for FILEPATH in "${LOCALFILES[@]}"
do
  RELPATH=`echo "$FILEPATH" |awk '{s=$0; sub("^'${LOCALDIR}'/","",s); print s}'`
  OUTFILE="${RELPATH}.gpg"
  if grep "${OUTFILE}\$" ${S3LIST} >/dev/null ; then
    DUPLICATES=`expr $DUPLICATES + 1`
    #echo "Not copying ${FILEPATH} (${OUTFILE} already exists)"
  else
    echo "Copying ${FILEPATH} (${OUTFILE} did not exist)"
    NUMCOPY=`expr $NUMCOPY + 1`
    cat "${FILEPATH}" |gpg -c --cipher-algo AES256 --passphrase "${PASSPHRASE}" | ${AWSCLI} s3 cp - "s3://${S3BUCKET}/${OUTFILE}"
  fi
  if [ $NUMCOPY -ge $MAXCOPY ] ; then
    echo "Exiting after copying $MAXCOPY files and skipping $DUPLICATES duplicates"
    break
  fi
done

rm ${S3LIST} ${LOCALLIST}
echo "Done `date`"

