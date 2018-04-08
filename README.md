# savethepictures
Save my pictures in a redundant and secure way

- Get a Raspberry PI, or similar, to be the local (in your home) backup server
- Install Raspbian on the PI
- Install [AWS CLI](https://aws.amazon.com/cli/) on the PI - `pip install awscli`
- Install [OpenGPG](https://www.openpgp.org/) on the PI - `apt-get install gpgv`
- Install cronjob `crontab.pi` on the PI (this job will sync encrypted files to S3)
- Install cronjob `cronjob.desktop` on your desktop Mac/Linux machine (this job syncs plaintext files to your desktop)
- Use e.g. [Foldersync](https://play.google.com/store/apps/details?id=dk.tacit.android.foldersync.full&hl=en) to sync photos etc from your mobile device to the PI, using SSH/SCP
