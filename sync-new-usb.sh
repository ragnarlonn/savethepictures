#!/bin/bash

AWSCLI=/usr/local/bin/aws
S3BUCKET=ragnar-lonn-org

usage() {
  echo "Usage: $1 <src-path> <dest-path> <rsa-passphrase> <max-copy> <parallellise>"
  echo ""
  echo "Example: $1 /mnt /media/usb1 mysecretpassphrase 1000"
  echo ""
  echo "  1. recursively copy from /mnt to /media/usb1 the files that do not exist there"
  echo "  2. build a file list of all files on s3 and then:"
  echo "  3. find out if any s3 files do not exist locally in /media/usb1 and if so, download and decrypt"
  echo ""
  echo "Example: $1 /dev/null /media/usb1 mysecretpassphrase 1000 4"
  echo ""
  echo "  Use above to populate/restore contents from S3 to local storage (/media/usb1)"
  echo "  4 threads will be used, to speed things up"
  echo ""
  exit 1
}

createdir() {
  DIR=`dirname "$1"`
  [ -d "${DIR}" ] || mkdir -p "${DIR}"
}

[ $# -ge 4 ] || usage $0

SRCDIR=$1
DSTDIR=$2
PASSPHRASE=$3
MAXCOPY=$4

THREADS=1
if [ $# -eq 5 ]; then
  THREADS=$5
  echo "Using $THREADS threads"
fi

S3LIST=/tmp/s3filelist.$$.tmp
SRCLIST=/tmp/localfilelist1.$$.tmp
DSTLIST=/tmp/localfilelist2.$$.tmp

NUMCOPY=0
SRCDUPLICATES=0
S3DUPLICATES=0

echo "Starting `date`"

# Build list of files in SRCDIR
find ${SRCDIR} -type f >${SRCLIST}
FILES=`wc -l ${SRCLIST} |awk '{print $1}'`
echo "Files in ${SRCDIR}: ${FILES}"

# Build list of files already in DSTDIR
find ${DSTDIR} -type f >${DSTLIST}
FILES=`wc -l ${DSTLIST} |awk '{print $1}'`
echo "Files in ${DSTDIR}: ${FILES}"

# Iterate over SRCDIR files, copying those that did not exist in DSTDIR
IFS=$'\r\n' GLOBIGNORE='*' command eval 'SRCFILES=($(cat '${SRCLIST}'))'
for FILEPATH in "${SRCFILES[@]}"
do
  if [ $NUMCOPY -ge $MAXCOPY ] ; then
    echo "Exiting after copying $MAXCOPY files and skipping $SRCDUPLICATES sourcedir duplicates"
    break
  fi
  RELPATH=`echo "$FILEPATH" |awk '{s=$0; sub("^'${SRCDIR}'/","",s); print s}'`
  OUTFILE="${DSTDIR}/${RELPATH}"
  if grep "${RELPATH}\$" ${DSTLIST} >/dev/null ; then
    SRCDUPLICATES=`expr $SRCDUPLICATES + 1`
    echo "SRCDUPLICATE: Not copying ${FILEPATH} (${OUTFILE} already exists)"
  else
    echo "Copying ${FILEPATH} (${OUTFILE} did not exist)"
    createdir "${OUTFILE}"
    NUMCOPY=`expr $NUMCOPY + 1`
    cp "${FILEPATH}" "${OUTFILE}"
  fi
done

if [ $NUMCOPY -ge $MAXCOPY ] ; then
  echo "Stopping after $MAXCOPY files"
  echo "Done `date`"
  rm $SRCLIST $DSTLIST
  exit 0
fi

#
# Copy stuff from S3
#

# Recreate list of DSTDIR files
find ${DSTDIR} -type f >${DSTLIST}

# Create a list of all files currently in the S3 bucket
${AWSCLI} s3 ls --recursive s3://${S3BUCKET} >$S3LIST
#2017-02-04 21:14:56          5 hej/hopp
#2017-02-04 21:18:36          4 hej/san/sa
#2017-02-05 10:17:42          3 hej/san/saa
FILES=`wc -l ${S3LIST} |awk '{print $1}'`
echo "Files in s3://${S3BUCKET}: ${FILES}"

# Iterate over s3 files, copying and decrypting those that we don't have locally
if [ $FILES -lt $THREADS ] ; then
  echo "Only $FILES files, adjusting THREADS to $FILES"
  THREADS=$FILES
fi

# Use a log file to keep track of files copied 
# (so we know how many have been copied)files and duplicates
COPIEDLOG=/tmp/copied.$$
DUPLICATESLOG=/tmp/duplicates.$$
touch $COPIEDLOG
touch $DUPLICATESLOG
_COPIEDLOCK=$(mktemp /tmp/_copiedlock.$$)
_DUPLICATESLOCK=$(mktemp /tmp/_duplicateslock.$$)
COPIEDLOCK=/tmp/copiedlock.$$
DUPLICATESLOCK=/tmp/duplicateslock.$$
trap "rm $_COPIEDLOCK $_DUPLICATESLOCK $S3LIST $SRCLIST $DSTLIST $COPIEDLOCK $DUPLICATESLOCK $COPIEDLOG $DUPLICATESLOG" EXIT

lock() {
  TEMPFILE=$1
  LOCKFILE=$2
  for i in {1..300}
  do
    if ln $TEMPFILE $LOCKFILE >/dev/null 2>&1 ; then
      return
    fi
    sleep .1
  done
  exit 1
}

FILESPERTHREAD=`expr $FILES / $THREADS`
IFS=$'\r\n' GLOBIGNORE='*' command eval 'S3FILES=($(cat '${S3LIST}'))'
declare -a PIDS=()
for (( j = 0; j < $THREADS; j++ ))
do
  (
    START=`echo "scale=0; ($j * $FILESPERTHREAD + 1.5)/1" |bc`
    END=`echo "scale=0; (($j + 1) * $FILESPERTHREAD + 0.5)/1" |bc`
    NUM=`echo "$END - $START + 1" |bc`
    for FILEPATH in "${S3FILES[@]:${START}:${NUM}}"
    do
      COPIED=`wc -l $COPIEDLOG |awk '{print $1}'`
      if [ $COPIED -ge $MAXCOPY ] ; then
        break
      fi
      S3PATH=`echo "$FILEPATH" |cut -c32-`
      ORIGPATH=`echo $S3PATH |sed 's/\.gpg//'`
      if grep "${ORIGPATH}\$" ${DSTLIST} >/dev/null ; then
        #echo "Thread $j not downloading ${S3PATH} (${DSTDIR}/${ORIGPATH} already exists)"
        lock $_DUPLICATESLOCK $DUPLICATESLOCK
        echo "$S3PATH" >>$DUPLICATESLOG
        rm $DUPLICATESLOCK
      else
        OUTFILE="${DSTDIR}/${ORIGPATH}"
        S3FULLPATH="s3://${S3BUCKET}/${S3PATH}"
        echo 'Thread '$j' downloading "'${S3PATH}'" ('"${OUTFILE} did not exist)"
        createdir "${OUTFILE}"
        ${AWSCLI} s3 cp "${S3FULLPATH}" - |gpg -q -d --cipher-algo AES256 --passphrase "${PASSPHRASE}" >"${OUTFILE}"
        lock $_COPIEDLOCK $COPIEDLOCK
        echo "$S3PATH" >>$COPIEDLOG
        rm $COPIEDLOCK
      fi

#      S3PATH=`echo "$FILEPATH" |cut -c32-`
#      ORIGPATH=`echo $S3PATH |sed 's/\.gpg//'`
#      if grep "${ORIGPATH}\$" ${DSTLIST} >/dev/null ; then
#        S3DUPLICATES=`expr $S3DUPLICATES + 1`
#        #echo "Not downloading ${S3PATH} (${DSTDIR}/${ORIGPATH} already exists)"
#      else
#        OUTFILE="${DSTDIR}/${ORIGPATH}"
#        echo "Downloading ${S3PATH} (${OUTFILE} did not exist)"
#        NUMCOPY=`expr $NUMCOPY + 1`
#        createdir "${OUTFILE}"
#        ${AWSCLI} s3 cp "s3://${S3BUCKET}/${S3PATH}" - |gpg -d --cipher-algo AES256 --passphrase "${PASSPHRASE}" >"${OUTFILE}"
#      fi

    done
    COPIED=`wc -l $COPIEDLOG |awk '{print $1}'`
    DUPLICATES=`wc -l $DUPLICATESLOG |awk '{print $1}'`
    echo "Thread $j exiting (total $COPIED copied files and $DUPLICATES s3 duplicates)"
  ) &
  PIDS[${j}]=$!
done
for PID in ${PIDS[*]}; do
    wait $PID
done

#[ -e ${S3LIST} ] && rm ${S3LIST}
#[ -e ${SRCLIST} ] && rm ${SRCLIST}
#[ -e ${DSTLIST} ] && rm ${DSTLIST}
#[ -e ${_COPIEDLOCK} ] && rm ${_COPIEDLOCK}
#[ -e ${COPIEDLOCK} ] && rm ${COPIEDLOCK}
#[ -e ${_DUPLICATESLOCK} ] && rm ${_DUPLICATESLOCK}
#[ -e ${DUPLICATESLOCK} ] && rm ${DUPLICATESLOCK}
#[ -e ${COPIEDLOG} ] && rm ${COPIEDLOG}
#[ -e ${DUPLICATESLOG} ] && rm ${DUPLICATESLOG}
echo "Done `date`"
