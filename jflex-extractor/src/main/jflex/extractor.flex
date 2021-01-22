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

%state SELECT, INSERT, DELETE, UPDATE, MERGE

%{
  // you can reference a table in the FROM clause in one of the following ways:
  //   table
  //   table t
  //   table as t
  // in other words, you need max 3 identifiers to reference a table
  private static final int FROM_TABLE_REF_MAX_IDENTIFIERS = 3;

  private int parenLevel = 0;
  private String mainTable = null;
  private boolean expectingTableName = false;

  // select only
  private boolean mainTableSetAlready = false;
  private int identifiersAfterMainFromClause = 0;

  private SqlStatementInfo getResult(String fullStatement) {
    switch (yystate()) {
      case SELECT: return new SqlStatementInfo(fullStatement, "SELECT", mainTable);
      case INSERT: return new SqlStatementInfo(fullStatement, "INSERT", mainTable);
      case DELETE: return new SqlStatementInfo(fullStatement, "DELETE", mainTable);
      case UPDATE: return new SqlStatementInfo(fullStatement, "UPDATE", mainTable);
      case MERGE:  return new SqlStatementInfo(fullStatement, "MERGE", mainTable);
      default:     return new SqlStatementInfo(fullStatement, null, null);
    }
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

// Comments and parentheses are handled in all states
{COMMENT} | {WHITESPACE} {}
{OPEN_PAREN}             { parenLevel += 1; }
{CLOSE_PAREN}            { parenLevel -= 1; }

<YYINITIAL> {
  "SELECT" { yybegin(SELECT); System.out.println("SELECT"); }
  "INSERT" { yybegin(INSERT); System.out.println("INSERT"); }
  "DELETE" { yybegin(DELETE); System.out.println("DELETE"); }
  "UPDATE" { yybegin(UPDATE); System.out.println("UPDATE"); }
  "MERGE"  { yybegin(MERGE);  System.out.println("MERGE");  }

// TODO: HERE!!!!!!!
  .+ { System.out.println("ANYTHING"); }
}

<SELECT> {
  "FROM" {
          if (parenLevel == 0) {
            // main query FROM clause
            expectingTableName = true;
          } else {
            // subquery in WITH or SELECT clause, before main FROM clause; skipping
            mainTable = null;
            return YYEOF;
          }
      }

  "JOIN" {
          // for SELECT statements with joined tables there's no main table
          mainTable = null;
          return YYEOF;
      }

  {IDENTIFIER} {
          if (identifiersAfterMainFromClause > 0) {
            ++identifiersAfterMainFromClause;
          }

          if (expectingTableName) {
            // SELECT FROM (subquery) case
            if (parenLevel != 0) {
              mainTable = null;
              return YYEOF;
            }

            // whenever >1 table is used there is no main table (e.g. unions)
            if (mainTableSetAlready) {
              mainTable = null;
              return YYEOF;
            }

            mainTable = yytext();
            mainTableSetAlready = true;
            expectingTableName = false;
            // start counting identifiers after encountering main from clause
            identifiersAfterMainFromClause = 1;

            // continue scanning the query, there may be more than one table (e.g. joins)
          }
      }

  {COMMA} {
          // comma was encountered in the FROM clause, i.e. implicit join
          // (if less than 3 identifiers have appeared before first comma then it means that it's a table list;
          // any other list that can appear later needs at least 4 idents)
          if (identifiersAfterMainFromClause > 0
              && identifiersAfterMainFromClause <= FROM_TABLE_REF_MAX_IDENTIFIERS) {
            mainTable = null;
            return YYEOF;
          }
      }

  .+ {}
}

<INSERT> {
  "INTO" {
          expectingTableName = true;
      }

  {IDENTIFIER} {
          if (expectingTableName) {
            mainTable = yytext();
            return YYEOF;
          }
      }

  .+ {}
}

<DELETE> {
  "FROM" {
          expectingTableName = true;
      }

  {IDENTIFIER} {
          if (expectingTableName) {
            mainTable = yytext();
            return YYEOF;
          }
      }

  .+ {}
}

<UPDATE> {
  {IDENTIFIER} {
          mainTable = yytext();
          return YYEOF;
      }
}

<MERGE> {
  // just skip keyword "INTO" that appears in some SQL variants
  "INTO" {}

  {IDENTIFIER} {
          mainTable = yytext();
          return YYEOF;
      }

  .+ {}
}
