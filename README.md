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
- The only time a file is backed up to S3 is when the system identifies a new, unique file path that does not already exist on S3. This means that it old backups will never be overwritten unless you delete the backup files manually.

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

- Foldersync and the crontabs should run automatically, keeping data backed up and in sync

- Occasionally, buy a new USB memory stick and store the old one in a safe place (e.g. a bank vault). Or just use two memory sticks that you swap occasionally. The point is to keep one physical storage device that is completely disconnected from all networks, ensuring that someone hacking your online presence cannot delete all your data.

- Swapping memory sticks requires you to sync data from the old stick to the new before replacing it, of course.
