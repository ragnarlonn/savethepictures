# savethepictures

A very simple backup system, to save especially family pictures and videos but also any other data you
want to keep safe.

This setup allows you to:

- Automatically back up your pictures & videos from your mobile device to a Linux file server in your home
- Automatically back up ENCRYPTED versions of those files to the public cloud (an Amazon S3 bucket)
- Keep any number of unencrypted copies of the backups on machines that you control (like your regular desktop machine)
- Keep a physical backup copy of your stuff in e.g. a bank vault

Worth noting:

- All communication happens over encrypted SSH/SCP.
- The only time a file is backed up to S3 is when the system identifies a new, unique file path that does not already exist on S3. This means that it *old backups will never be overwritten* unless you delete the backup files manually.

### Instructions

- Get a [Raspberry PI](https://www.raspberrypi.org/), or similar, to be the local (in your home) backup server
- Get a sufficiently large USB memory stick and plug it into the Raspberry PI
- Install [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) on the PI
- Install [AWS CLI](https://aws.amazon.com/cli/) on the PI - `pip install awscli`
- Install [OpenGPG](https://www.openpgp.org/) on the PI - `apt-get install gpgv`
- Format the USB memory stick and mount it on the Raspbian server
- Create an Amazon S3 bucket to use for encrypted file backups
- Put the sync-oneway-to-s3.sh script somewhere on the PI server, and modify it so the variables S3BUCKET is the correct name of your S3 bucket and LOCALDIR refers to the mount point of your USB memory stick
- Install cronjob `crontab.pi` on the PI (this job will execute sync-oneway-to-s3.sh once/day). Make sure the path to the sync-oneway-to-s3.sh script is OK and change the PASSPHRASE (used to gpg-encrypt files sent to S3) to something secret
- Install cronjob `cronjob.desktop` on your desktop Mac/Linux machine (this job syncs plaintext files to your desktop). Make sure the rsync paths are correct.
- Use e.g. [Foldersync](https://play.google.com/store/apps/details?id=dk.tacit.android.foldersync.full&hl=en) to sync photos etc from your mobile device to the PI, using SSH/SCP. Sync to the mount dir of the USB memory stick


### Operations

- Foldersync and the crontabs should run automatically, keeping data backed up and in sync but __never__ overwrite old data anywhere (you may need to configure Foldersync to behave that way when it is copying things to the raspberry PI server)

- Occasionally, buy a new USB memory stick and store the old one in a safe place (e.g. a bank vault). Or just use two memory sticks that you swap occasionally. The point is to keep one physical storage device that is completely disconnected from all networks, ensuring that someone hacking your online presence cannot delete all your data.

- Swapping memory sticks requires you to sync data from the old stick to the new before replacing it, of course. 

### Syncing a new USB stick

The script sync-new-usb.sh will copy files from an existing USB memory (i.e. its mount point, or any directory path you point it to) to a new memory and *also* check S3 storage for any files there that didn't exist locally. Any S3 files that weren't found locally will be downloaded and decrypted before being stored on the new USB memory.

*First edit the script and enter the name of your S3 bucket, at the top of the script*

`./sync-new-usb.sh /media/usb1 /mnt mysecretpassphrase 1000`

The above command will check what files exist under /media/usb1 that do not exist under /mnt and then copy those to /mnt. Then it will also check if there are any files in the S3 bucket (but with a .gpg ending) that don't exist locally. Such files will be downloaded from S3 and decrypted using the passphrase "mysecretpassphrase". Max 1000 files will be copied, in total. Then the script exits. You can run the script multiple times with the same parameters, copying new files each time as it will not overwrite old files.




