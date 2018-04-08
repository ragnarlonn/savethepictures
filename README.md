# savethepictures

A very simple backup system, to save especially family pictures and videos but also any other data you
want to keep safe.

This setup allows you to:

- Automatically back up your pictures & videos from your mobile device to a Linux file server in your home
- Automatically back up ENCRYPTED versions of those files to the public cloud (an Amazon S3 bucket)
- Keep any number of unencrypted copies of the backups on machines that you control (like your regular desktop machine)

All communication happens over encrypted SSH/SCP.

### Instructions

- Get a [Raspberry PI](https://www.raspberrypi.org/), or similar, to be the local (in your home) backup server
- Install [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) on the PI
- Install [AWS CLI](https://aws.amazon.com/cli/) on the PI - `pip install awscli`
- Install [OpenGPG](https://www.openpgp.org/) on the PI - `apt-get install gpgv`
- Install cronjob `crontab.pi` on the PI (this job will sync encrypted files to S3)
- Install cronjob `cronjob.desktop` on your desktop Mac/Linux machine (this job syncs plaintext files to your desktop)
- Use e.g. [Foldersync](https://play.google.com/store/apps/details?id=dk.tacit.android.foldersync.full&hl=en) to sync photos etc from your mobile device to the PI, using SSH/SCP
