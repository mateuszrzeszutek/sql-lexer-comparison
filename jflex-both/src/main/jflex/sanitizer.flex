%%

%public
%final
%class SqlSanitizer
%apiprivate
%int
%buffer 2048

%unicode
%ignorecase

COMMA             = ","
OPEN_PAREN        = "("
CLOSE_PAREN       = ")"
COMMENT           = "/*" ([^*] | "*"+ [^/*])* "*/"
IDENTIFIER        = ([:letter:] | "_") ([:letter:] | [0-9] | [_.])*
BASIC_NUM         = [.+-]* [0-9] ([0-9] | [e.+-])*
HEX_NUM           = "0x" ([a-f] | [0-9])+
QUOTED_STR        = "'" ("''" | [^'])* "'"
DOUBLE_QUOTED_STR = "\"" ("\"\"" | [^\"])* "\""
DOLLAR_QUOTED_STR = "$$" [^$]* "$$"
WHITESPACE        = [ \t\r\n]+

%{
  // max length of the sanitized statement - SQLs longer than this will be trimmed
  private static final int LIMIT = 32 * 1024;

  private final StringBuilder builder = new StringBuilder();

  private void appendCurrentFragment() {
    builder.append(zzBuffer, zzStartRead, zzMarkedPos - zzStartRead);
  }

  private boolean isOverLimit() {
    return builder.length() > LIMIT;
  }

  // you can reference a table in the FROM clause in one of the following ways:
  //   table
  //   table t
  //   table as t
  // in other words, you need max 3 identifiers to reference a table
  private static final int FROM_TABLE_REF_MAX_IDENTIFIERS = 3;

  private int parenLevel = 0;
  private Operation operation = NoOp.INSTANCE;
  private boolean extractionDone = false;

  private void setOperation(Operation operation) {
    if (this.operation == NoOp.INSTANCE) {
      this.operation = operation;
    }
  }

  private static abstract class Operation {
    String mainTable = null;

    /** @return true if all statement info is gathered */
    boolean handleFrom() {
      return false;
    }

    /** @return true if all statement info is gathered */
    boolean handleInto() {
      return false;
    }

    /** @return true if all statement info is gathered */
    boolean handleJoin() {
      return false;
    }

    /** @return true if all statement info is gathered */
    boolean handleIdentifier() {
      return false;
    }

    /** @return true if all statement info is gathered */
    boolean handleComma() {
      return false;
    }

    SqlStatementInfo getResult(String fullStatement) {
      return new SqlStatementInfo(fullStatement, getClass().getSimpleName().toUpperCase(), mainTable);
    }
  }

  private static class NoOp extends Operation {
    static final Operation INSTANCE = new NoOp();

    SqlStatementInfo getResult(String fullStatement) {
      return new SqlStatementInfo(fullStatement, null, null);
    }
  }

  private class Select extends Operation {
    // you can reference a table in the FROM clause in one of the following ways:
    //   table
    //   table t
    //   table as t
    // in other words, you need max 3 identifiers to reference a table
    private static final int FROM_TABLE_REF_MAX_IDENTIFIERS = 3;

    boolean expectingTableName = false;
    boolean mainTableSetAlready = false;
    int identifiersAfterMainFromClause = 0;

    boolean handleFrom() {
      if (parenLevel == 0) {
        // main query FROM clause
        expectingTableName = true;
        return false;
      } else {
        // subquery in WITH or SELECT clause, before main FROM clause; skipping
        mainTable = null;
        return true;
      }
    }

    boolean handleJoin() {
      // for SELECT statements with joined tables there's no main table
      mainTable = null;
      return true;
    }

    boolean handleIdentifier() {
      if (identifiersAfterMainFromClause > 0) {
        ++identifiersAfterMainFromClause;
      }

      if (!expectingTableName) {
        return false;
      }

      // SELECT FROM (subquery) case
      if (parenLevel != 0) {
        mainTable = null;
        return true;
      }

      // whenever >1 table is used there is no main table (e.g. unions)
      if (mainTableSetAlready) {
        mainTable = null;
        return true;
      }

      mainTable = yytext();
      mainTableSetAlready = true;
      expectingTableName = false;
      // start counting identifiers after encountering main from clause
      identifiersAfterMainFromClause = 1;

      // continue scanning the query, there may be more than one table (e.g. joins)
      return false;
    }

    boolean handleComma() {
      // comma was encountered in the FROM clause, i.e. implicit join
      // (if less than 3 identifiers have appeared before first comma then it means that it's a table list;
      // any other list that can appear later needs at least 4 idents)
      if (identifiersAfterMainFromClause > 0
          && identifiersAfterMainFromClause <= FROM_TABLE_REF_MAX_IDENTIFIERS) {
        mainTable = null;
        return true;
      }
      return false;
    }
  }

  private class Insert extends Operation {
    boolean expectingTableName = false;

    boolean handleInto() {
      expectingTableName = true;
      return false;
    }

    boolean handleIdentifier() {
      if (!expectingTableName) {
        return false;
      }

      mainTable = yytext();
      return true;
    }
  }

  private class Delete extends Operation {
    boolean expectingTableName = false;

    boolean handleFrom() {
      expectingTableName = true;
      return false;
    }

    boolean handleIdentifier() {
      if (!expectingTableName) {
        return false;
      }

      mainTable = yytext();
      return true;
    }
  }

  private class Update extends Operation {
    boolean handleIdentifier() {
      mainTable = yytext();
      return true;
    }
  }

  private class Merge extends Operation {
    boolean handleIdentifier() {
      mainTable = yytext();
      return true;
    }
  }

  private SqlStatementInfo getResult() {
    if (builder.length() > LIMIT) {
      builder.delete(LIMIT, builder.length());
    }
    String fullStatement = builder.toString();
    return operation.getResult(fullStatement);
  }

  public static SqlStatementInfo sanitize(String statement) {
    SqlSanitizer sanitizer = new SqlSanitizer(new java.io.StringReader(statement));
    try {
      while (!sanitizer.yyatEOF()) {
        int token = sanitizer.yylex();
        if (token == YYEOF) {
          break;
        }
      }
      return sanitizer.getResult();
    } catch (java.io.IOException e) {
      return new SqlStatementInfo(null, null, null);
    }
  }

%}

%%

<YYINITIAL> {

  "SELECT" {
          appendCurrentFragment();
          setOperation(new Select());
          if (isOverLimit()) return YYEOF;
      }
  "INSERT" {
          appendCurrentFragment();
          setOperation(new Insert());
          if (isOverLimit()) return YYEOF;
      }
  "DELETE" {
          appendCurrentFragment();
          setOperation(new Delete());
          if (isOverLimit()) return YYEOF;
      }
  "UPDATE" {
          appendCurrentFragment();
          setOperation(new Update());
          if (isOverLimit()) return YYEOF;
      }
  "MERGE" {
          appendCurrentFragment();
          setOperation(new Merge());
          if (isOverLimit()) return YYEOF;
      }

  "FROM" {
          appendCurrentFragment();
          if (!extractionDone) {
            extractionDone = operation.handleFrom();
          }
          if (isOverLimit()) return YYEOF;
      }
  "INTO" {
          appendCurrentFragment();
          if (!extractionDone) {
            extractionDone = operation.handleInto();
          }
          if (isOverLimit()) return YYEOF;
      }
  "JOIN" {
          appendCurrentFragment();
          if (!extractionDone) {
            extractionDone = operation.handleJoin();
          }
          if (isOverLimit()) return YYEOF;
      }
  {COMMA} {
          appendCurrentFragment();
          if (!extractionDone) {
            extractionDone = operation.handleComma();
          }
          if (isOverLimit()) return YYEOF;
      }
  {IDENTIFIER} {
          appendCurrentFragment();
          if (!extractionDone) {
            extractionDone = operation.handleIdentifier();
          }
          if (isOverLimit()) return YYEOF;
      }

  {OPEN_PAREN}  {
          appendCurrentFragment();
          parenLevel += 1;
          if (isOverLimit()) return YYEOF;
      }
  {CLOSE_PAREN} {
          appendCurrentFragment();
          parenLevel -= 1;
          if (isOverLimit()) return YYEOF;
      }

  // here is where the actual sanitization happens
  {BASIC_NUM} | {HEX_NUM} | {QUOTED_STR} | {DOUBLE_QUOTED_STR} | {DOLLAR_QUOTED_STR} {
          builder.append('?');
          if (isOverLimit()) return YYEOF;
      }

  {COMMENT} {
          appendCurrentFragment();
          if (isOverLimit()) return YYEOF;
      }
  {WHITESPACE} {
          builder.append(' ');
          if (isOverLimit()) return YYEOF;
      }
  [^] {
          appendCurrentFragment();
          if (isOverLimit()) return YYEOF;
      }
}
