import static java.nio.file.StandardOpenOption.CREATE;
import static java.nio.file.StandardOpenOption.TRUNCATE_EXISTING;

import java.io.IOException;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;

public class Main {
  public static void main(String[] args) throws IOException, ParseException {
    if (args.length < 1) {
      System.err.println("Required argument missing: path to the SQL examples file");
      System.exit(1);
    }

    var testFile = Paths.get(args[0]);
    if (Files.isDirectory(testFile)) {
      testDirectoryWithMultipleFiles(testFile);
    } else {
      testSingleFileWithMultipleStatements(testFile);
    }
  }

  private static void testDirectoryWithMultipleFiles(Path testDir) throws IOException, ParseException {
    for (int i = 0; i < 100; i++) {
      var outFile = Paths.get("out");
      try (var out = Files.newBufferedWriter(outFile, CREATE, TRUNCATE_EXISTING);
           var dir = Files.newDirectoryStream(testDir, Files::isRegularFile)) {
        for (Path testFile : dir) {
          String statement = Files.readString(testFile);
          var info = SqlStatementInfoExtractor.extract(statement);
          out.append(info.toString()).append(info.getFullStatement()).append("\n");
        }
      }
    }
  }

  private static void testSingleFileWithMultipleStatements(Path testFile) throws IOException, ParseException {
    for (int i = 0; i < 100; i++) {
      List<String> sqlStatements = Files.readAllLines(testFile);

      var outFile = Paths.get("out");
      try (Writer out = Files.newBufferedWriter(outFile, CREATE, TRUNCATE_EXISTING)) {
        for (String statement : sqlStatements) {
          var info = SqlStatementInfoExtractor.extract(statement);
          out.append(info.toString()).append(info.getFullStatement()).append("\n");
        }
      }
    }
  }
}
