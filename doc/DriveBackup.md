### About

DriveBackup makes downloads and exports of Google Drive documents to the local filesystem.

Files that were uploaded in a specific format (e.g. PDF, PowerPoint) will be downloaded as is. Files in Google native format will be exported to MS Office counter parts or to PDF.

The files are named after the document title, plus the Google document ID to ensure uniqueness.

The primary goal is to guard against total loss of our documents should our Google Apps account become unavailable.

There are two core pieces: 

  - `DriveBackup.java` : Uses Google Drive API to authenticate to Google, retrieve list of files and then download or export to disk those documents that have been modified since the last backup. 
  
  - `budoc` : Perl wrapper that manages the backup directory rotations and last backup timestamp (because I'm too lazy to port this legacy code to Java), and runs java invocation of DriveBackup.

`DriveBackup` uses a delegated Service account to impersonate a specific account user,
so only files that are visible to and readable by that account user will be backed up.

### Google Credentials Setup:

Follow instructions at https://developers.google.com/drive/web/delegation .

Briefly

  - Service account in a project of the Developers Console
    - This uses the `DocBackup` project.
    - https://console.developers.google.com/project
  - That Service account needs the drive.readonly delegation scope.
    - `DriveBackup.java` uses matching `DriveScopes.DRIVE_READONLY` for `GoogleCredential` construction.
  - PKCS12 file for the Service account in ~/.google/certs
    - https://console.developers.google.com/project/pioneering-axe-837/apiui/credential


### Application Configuration

#### Command line arguments for budoc

- The first argument is the path to the directory where backups will be stored.

        GoogleAppsForYourDomain/bin/budoc /eupath/data/EuPathDB/GoogleApps/DriveArchive
The directory must pre-exist. Rotation subdirectories will be created and managed by `budoc`.

- The number of backup rotations retained is defined for the `$max_rotations` variable in the `budoc` script.

#### Properties Configuration for DriveBackup

A Java property file is used for private configuration (things we don't want in SCM and that
we prefer not be exposed on the command line). The default file is `$HOME/.google/DriveBackup.properties` but can be 
changed with the `-configFile` option.

        userEmail=butest@apidb.org
        serviceEmail=290239191911-pfja1258bb7pwoqh0a23t2t3n06rmtkv@developer.gserviceaccount.com
        servicePkcs12FilePath=/home/mheiges/.google/certs/DocBackup-fa2afe42e0de.p12

#### Command line arguments for DriveBackup
See `@Options` annotations in `DriveBackup.java` for most up-to-date list and for details.

  - `-backupDir`
  - `-lastBackup`
  - `-docId`
  - `-loglevel`
  - `-configFile`


#### log4j configuration
  - `lib/java/log4j.xml`

### Running:

For routine backups, use the `budoc` script. Invoke it in cron.

    budoc <backup/directory> [optional doc ID]

The backup directory must pre-exist. 

For development, 

    java -classpath ${APPDIR}/:${APPDIR}/lib/java/*:${APPDIR}/lib/java:${APPDIR}/build \
      DriveBackup \
        -backupDir ${buDir}/1 \
        -configFile $HOME/.google/DriveBackup.properties \
        -lastBackup 1970-01-01T20:00:00.000Z \
        -loglevel TRACE \

### Building from source

There is a simple shell script to build DriveBackup.java
    bin/build

### About backup directory rotations

The `budoc` script manages numbered subdirectories under the backup directory. 
Each time the script runs it removes the highest numbered directory (`$max_rotations`) and 
copies the next numbered directory in its place (delete 4, copy 3 to 4)

- The last backup timestamp is stored in the `.lastrun` file in the backup directory.


### Known Issues

