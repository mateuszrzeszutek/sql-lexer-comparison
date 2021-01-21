import static java.nio.file.StandardOpenOption.CREATE;
import static java.nio.file.StandardOpenOption.TRUNCATE_EXISTING;

import java.io.IOException;
import java.io.Writer;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;

public class Main {
  public static void main(String[] args) throws IOException {
    if (args.length < 1) {
      System.err.println("Required argument missing: path to the SQL examples file");
      System.exit(1);
    }
    var testFile = Paths.get(args[0]);

    for (int i = 0; i < 100; i++) {
      List<String> sqlStatements = Files.readAllLines(testFile);

      var outFile = Paths.get("out");
      try (Writer out = Files.newBufferedWriter(outFile, CREATE, TRUNCATE_EXISTING)) {
        for (String statement : sqlStatements) {
          String sanitized = SqlSanitizer.sanitize(statement);
          out.append(sanitized).append("\n");
        }
      }
    }
  }
}
