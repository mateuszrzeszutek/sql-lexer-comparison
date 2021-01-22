%%

%public
%final
%class SqlInfoExtractor
%apiprivate
%int

%unicode
%ignorecase

COMMA       = ","
OPEN_PAREN  = "("
CLOSE_PAREN = ")"
COMMENT     = "/*" ([^*] | "*"+ [^/*])* "*/"
IDENTIFIER  = ([:letter:] | "_") ([:letter:] | [0-9] | [_.])*
WHITESPACE  = [ \t\r\n]+

%{
  // you can reference a table in the FROM clause in one of the following ways:
  //   table
  //   table t
  //   table as t
  // in other words, you need max 3 identifiers to reference a table
  private static final int FROM_TABLE_REF_MAX_IDENTIFIERS = 3;

  private int parenLevel = 0;
  private Operation operation = NoOp.INSTANCE;

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

  private SqlStatementInfo getResult(String fullStatement) {
    return operation.getResult(fullStatement);
  }

  public static SqlStatementInfo extract(String statement) {
    SqlInfoExtractor extractor = new SqlInfoExtractor(new java.io.StringReader(statement));
    try {
      while (!extractor.yyatEOF()) {
        int token = extractor.yylex();
        if (token == YYEOF) {
          break;
        }
      }
      return extractor.getResult(statement);
    } catch (java.io.IOException e) {
      return new SqlStatementInfo(statement, null, null);
    }
  }
%}

%%

<YYINITIAL> {
  "SELECT" { setOperation(new Select()); }
  "INSERT" { setOperation(new Insert()); }
  "DELETE" { setOperation(new Delete()); }
  "UPDATE" { setOperation(new Update()); }
  "MERGE"  { setOperation(new Merge()); }

  "FROM" {
          boolean done = operation.handleFrom();
          if (done) {
            return YYEOF;
          }
      }
  "INTO" {
          boolean done = operation.handleInto();
          if (done) {
            return YYEOF;
          }
      }
  "JOIN" {
          boolean done = operation.handleJoin();
          if (done) {
            return YYEOF;
          }
      }
  {COMMA} {
          boolean done = operation.handleComma();
          if (done) {
            return YYEOF;
          }
      }
  {IDENTIFIER} {
          boolean done = operation.handleIdentifier();
          if (done) {
            return YYEOF;
          }
      }

  {OPEN_PAREN}  { parenLevel += 1; }
  {CLOSE_PAREN} { parenLevel -= 1; }

  {COMMENT} | {WHITESPACE} | [^] {}
}
