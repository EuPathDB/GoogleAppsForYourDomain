import com.google.api.client.googleapis.auth.oauth2.GoogleCredential;
import com.google.api.client.googleapis.media.MediaHttpDownloader;
import com.google.api.client.http.FileContent;
import com.google.api.client.http.GenericUrl;
import com.google.api.client.http.HttpResponse;
import com.google.api.client.http.HttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.jackson2.JacksonFactory;
import com.google.api.client.util.DateTime;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.Drive.Files;
import com.google.api.services.drive.DriveScopes;
import com.google.api.services.drive.model.File;
import com.google.api.services.drive.model.FileList;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.OutputStream;
import java.security.GeneralSecurityException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.kohsuke.args4j.CmdLineException;
import org.kohsuke.args4j.CmdLineParser;
import org.kohsuke.args4j.Option;

public class DriveBackup {
  private static Logger logger = Logger.getLogger(DriveBackup.class);

  @Option(name="-backupDir", required=true, usage = "Pre-existing directory where backup files will go.")
  private static String backupDir;

  @Option(name="-lastBackup", required=true, usage = "Last backup time, in format 2015-02-03T04:50:46.000Z.")
  private static String lastBackup;

  @Option(name="-docId", required=false, usage = "Google document id to backup (useful for debugging).")
  private static String docId;
                       
  @Option(name="-loglevel", required=false, usage = "log4j log level.")
  private static String runtimeLoglevel;

  @Option(name="-configFile", required=false, usage = "Path to configuration property file.")
  private static String configFile = System.getProperty("user.home") + "/.google/DriveBackup.properties";

  /** Do not try to download these mime types (there is no download or export url). */
  private static final List<String> excludedMimeTypes = Arrays.asList(
    "application/vnd.google-apps.folder",
    "application/vnd.google-apps.form"
  );

  public static void main(String[] args) throws IOException, CmdLineException {

    new DriveBackup().doConfigure(args);
    logger.setLevel(Level.toLevel(runtimeLoglevel, Level.INFO));
    Properties prop = loadProperties(configFile);
    String userEmail = prop.getProperty("userEmail");
    String serviceEmail = prop.getProperty("serviceEmail");
    String servicePkcs12FilePath = prop.getProperty("servicePkcs12FilePath");

    logger.debug("Last backup was " + lastBackup);
    try {
      Drive service = getDriveService(userEmail, serviceEmail, servicePkcs12FilePath);
      if (service != null) {

        try {
          List<File> files = retrieveAllFiles(service);

          for (File file : files) {

            // when debugging, you can supply a single docId to work with
            // and skip all others 
            if ( docId != null && ! file.getId().equals(docId)) {
              continue;
            }

            if (excludedMimeTypes.contains(file.getMimeType())) {
              continue;
            }

            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.S'Z'");
            sdf.setTimeZone(java.util.TimeZone.getTimeZone("GMT"));
            Date lastBackupDate = sdf.parse(lastBackup);
            long lastBackupUnixtime = (long) lastBackupDate.getTime();
            /** File.getModifiedDate() can take a minute or so to reflect the
              * actual modification time. This means edits that happen just
              * before a backup will be missed. For example,
              *   - edit File at 9:59
              *   - backup at 10:00
              *     - File.getModifiedDate() has not yet updated, the new edit is not 
              *       noticed, so the File is skipped this time.
              *   - Take next back up at 11:00.
              *     - By now, File.getModifiedDate() returns 9:59 but that's before the 
              *       last 10:00 backup time so it's assumed it's already backed up
              *       and it is skipped again.
              * To work around we roll back the last backup timestamp by a few minutes.
              * So in the above example the last backup time becomes 9:55 instead of 10:00
              * and the 9:59 File edit gets handled.
              */
            long msOffset = (5 * 60 * 1000);

            long fileModifiedUnixTime = file.getModifiedDate().getValue();

            if (fileModifiedUnixTime < (lastBackupUnixtime - msOffset)) {
              logger.debug("Skipping '" + file.getTitle() + "', last modification " + file.getModifiedDate());
              continue;
            }
            
            if (file.getDownloadUrl() != null && file.getDownloadUrl().length() > 0) {
              logger.debug("Downloading doc ... ");
              downloadFile(service, backupDir, file);        
            } else if (file.getExportLinks() != null && file.getExportLinks().size() > 0) {
              logger.debug("Exporting doc ... ");
              exportFile(service, backupDir, file);
            } else {
              logger.warn("Unable to find download or export URL for ");
            }

            logger.info(file.getTitle());
            logger.debug(file.getTitle() + "(" + file.getId() + ") :: " + file.getModifiedDate() + " :: " + file.getMimeType());

          }

        } catch (java.lang.NullPointerException npe) {
          npe.printStackTrace();
          logger.fatal("Failed to retrieve files for account " + 
              userEmail + ". Confirm account is correct " +
              "and the service account has correct delegation in the " +
              "Admin control panel " + 
              "(https://admin.google.com/AdminHome?chromeless=1#OGX:ManageOauthClients)");
        } catch (Exception ioe) {
          logger.fatal("OOPS " + ioe);
        }
      } else {
        logger.fatal("Unable to get service");
      }
    } catch (GeneralSecurityException gse) {
      logger.fatal(gse);
    }


  }

  /**
   * Build and returns a Drive service object authorized with the service accounts
   * that act on behalf of the given user.
   *
   * @param userEmail The email of the user.
   * @return Drive service object that is ready to make requests.
   */
  public static Drive getDriveService(
      String userEmail, String serviceEmail, String servicePkcs12FilePath
    ) throws GeneralSecurityException, IOException {

    HttpTransport httpTransport = new NetHttpTransport();
    JacksonFactory jsonFactory = new JacksonFactory();
    GoogleCredential credential = new GoogleCredential.Builder()
        .setTransport(httpTransport)
        .setJsonFactory(jsonFactory)
        .setServiceAccountId(serviceEmail)
        .setServiceAccountScopes(Arrays.asList(DriveScopes.DRIVE_READONLY))
        .setServiceAccountUser(userEmail)
        .setServiceAccountPrivateKeyFromP12File(
            new java.io.File(servicePkcs12FilePath))
        .build();
    Drive service = new Drive.Builder(httpTransport, jsonFactory, null)
        .setHttpRequestInitializer(credential)
	      .setApplicationName("EuPathBackupDoc")
        .build();
    return service;
  }

  /**
   * Retrieve a list of File resources.
   *  https://developers.google.com/drive/v2/reference/files/list#examples
   *
   * @param service Drive API service instance.
   * @return List of File resources.
   */
  private static List<File> retrieveAllFiles(Drive service) throws IOException {
    List<File> result = new ArrayList<File>();
    Files.List request = service.files().list();
    do {
      try {
        FileList files = request.execute();
        result.addAll(files.getItems());
        request.setPageToken(files.getNextPageToken());
      } catch (IOException e) {
        System.out.println("An error occurred: " + e);
        request.setPageToken(null);
      }
    } while (request.getPageToken() != null &&
             request.getPageToken().length() > 0);

    return result;
  }

  /**
   * Retrieve document from given URL and write to a file on disk.
   * If a file of same name already exists on disk it will be deleted
   * before a new file is written.
   *
   * @param service Drive API service instance.
   * @param url The url for downloading or exporting.
   * @param filename The full pathname for file to write. The filename
   *  can not have invalid characters.
   * @return InputStream containing the file's content if successful,
   *         {@code null} otherwise.
   */
  private static void fetchAndWriteFile(Drive service, String url, String filename) {

      try {
        HttpResponse resp = service.getRequestFactory()
                .buildGetRequest(new GenericUrl(url))
                .execute();

        InputStream content = resp.getContent();
        byte[] buffer = new byte[8 * 1024];

        // Rotated backups are stored as hard links.
        // If the file has changed, break file hard link before writing.
        deleteIfExists(filename);

        try {
          OutputStream output = new FileOutputStream(filename);
          try {
            int bytesRead;
            while ((bytesRead = content.read(buffer)) != -1) {
              output.write(buffer, 0, bytesRead);
            }
          } finally {
            output.close();
          }
        } finally {
          content.close();
        }

        java.io.File fileOnDisk = new java.io.File(filename);
        if ( ! fileOnDisk.exists() ) {
          logger.warn("The file '" + filename + "' is not found on disk after writing.");
        }
        if (fileOnDisk.length() == 0) {
          logger.warn("Warning: The file '" + filename + "' is size 0.");
        }

      } catch (IOException e) {
        // An error occurred.
        e.printStackTrace();
      } catch (Exception ex) {
        ex.printStackTrace();
      }

    }


  /**
   * Export document to a file.
   * 
   * https://developers.google.com/drive/web/manage-downloads
   *
   * @param service Drive API service instance.
   * @param file Drive File instance.
   * @return InputStream containing the file's content if successful,
   *         {@code null} otherwise.
   */
  private static void exportFile(Drive service, String backupDir, File file) {
    if (file.getExportLinks() != null && file.getExportLinks().size() > 0) {
      String exportMimeType = getExpMimeTypeForSrcMimeType(file.getMimeType());
      String fileExt = getFileExtForMimeType(file.getMimeType()) ;
      String basename = file.getTitle().replaceAll("/", "%2f");
      String filename = backupDir + "/" + basename + "__[" + file.getId() + "]." + fileExt;
      fetchAndWriteFile(service, file.getExportLinks().get(exportMimeType), filename);
    } else {
      logger.warn("The file " + file.getTitle() + " doesn't have any content stored on Drive.");
    }
    
  }

  /**
   * Download a file's content.
   * 
   * https://developers.google.com/drive/web/manage-downloads
   *
   * @param service Drive API service instance.
   * @param file Drive File instance.
   * @return InputStream containing the file's content if successful,
   *         {@code null} otherwise.
   */
  private static void downloadFile(Drive service, String backupDir, File file) {
    if (file.getDownloadUrl() != null && file.getDownloadUrl().length() > 0) {
      String basename = file.getTitle().replaceAll("/", "%2f");
      String filename = backupDir + "/" + basename;
      fetchAndWriteFile(service, file.getDownloadUrl(), filename);
    } else {
      logger.warn("The file " + file.getTitle() + " doesn't have any content stored on Drive.");
    }
  }

  /**
    * Delete given filename if it exists.
    *
    * @param The full pathname of file to delete.
    */
  private static void deleteIfExists(String filename) {
    java.io.File file = new java.io.File(filename);
    if (file.exists())
      file.delete();
  }

  /**
    * Parse commandline args with args4j. For examples see
    * https://github.com/kohsuke/args4j/blob/master/args4j/examples/SampleMain.java
    *
    * @param args from {@code main()}
    */
  private void doConfigure(String[] args) throws CmdLineException {
    CmdLineParser parser = new CmdLineParser(this);
    try {
      parser.parseArgument(args);
    } catch (CmdLineException e) {
      logger.fatal(e.getMessage());
      parser.printUsage(System.err);
      System.exit(1);
    }
  }

  /**
   * Get file name extension for export file for given Google document mime type.
   *
   * @param mime type of Google document, e.g. File.getMimeType()
   * @return String file name extension for exported file.
   *         {@code bin} otherwise.
   */
  private static String getFileExtForMimeType(String mimeType) {
    Map<String, String> googleMimeToFileExtension;
    googleMimeToFileExtension = new HashMap<String, String>();
    googleMimeToFileExtension.put("application/vnd.google-apps.document", "doc");
    googleMimeToFileExtension.put("application/vnd.google-apps.spreadsheet", "xls");
    googleMimeToFileExtension.put("application/vnd.google-apps.presentation", "ppt");
    googleMimeToFileExtension.put("application/vnd.google-apps.drawing", "pdf");
    String retVal = googleMimeToFileExtension.get(mimeType);
    if (retVal != null)
      return retVal;
    else
      return "bin";
  }


  /**
   * Get mime type for export file for given Google document mime type.
   *
   * @param mime type of Google document, e.g. File.getMimeType()
   * @return String mime type for exported file.
   *         {@code application/pdf} otherwise.
   */
  private static String getExpMimeTypeForSrcMimeType(String mimeType) {
    Map<String, String> googleMimeToFileMime;
    googleMimeToFileMime = new HashMap<String, String>();
    googleMimeToFileMime.put("application/vnd.google-apps.document", "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    googleMimeToFileMime.put("application/vnd.google-apps.spreadsheet", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    googleMimeToFileMime.put("application/vnd.google-apps.presentation", "application/vnd.openxmlformats-officedocument.presentationml.presentation");
    googleMimeToFileMime.put("application/vnd.google-apps.drawing", "application/pdf");
    String retVal = googleMimeToFileMime.get(mimeType);
    if (retVal != null)
      return retVal;
    else
      return "application/pdf";
  }

  /**
   * Load configuration property file.
   *
   * @param full path to property file
   * @return Properties
   */
  private static Properties loadProperties(String propFile) {
    Properties prop = new Properties();
    InputStream input = null;
    try {
      input = new FileInputStream(propFile);
      prop.load(input);
    } catch (IOException ex) {
      ex.printStackTrace();
    } finally {
      if (input != null) {
        try {
          input.close();
        } catch (IOException e) {
          e.printStackTrace();
        }
      }
    }
    return prop;
  }
}