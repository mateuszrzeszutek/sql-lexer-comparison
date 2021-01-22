%%

%public
%final
%class SqlSanitizer
%apiprivate
%int

%unicode
%ignorecase

IDENTIFIER        = ([:letter:] | "_") ([:letter:] | [0-9] | [_.])*
BASIC_NUM         = [.+-]* [0-9] ([0-9] | [e.+-])*
HEX_NUM           = "0x" ([a-f] | [0-9])+
QUOTED_STR        = "'" ("''" | [^'])* "'"
DOUBLE_QUOTED_STR = "\"" ("\"\"" | [^\"])* "\""
DOLLAR_QUOTED_STR = "$$" [^$]* "$$"
WHITESPACE        = [ \t\r\n]+

%{
  private static final int LIMIT = 32 * 1024;

  private final StringBuilder builder = new StringBuilder();

  private void appendCurrentFragment() {
    builder.append(zzBuffer, zzStartRead, zzMarkedPos - zzStartRead);
  }

  private boolean isOverLimit() {
    return builder.length() > LIMIT;
  }

  private String getResult() {
    if (builder.length() > LIMIT) {
      builder.delete(LIMIT, builder.length());
    }
    return builder.toString();
  }

  public static String sanitize(String statement) {
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
      return null;
    }
  }

%}

%%

<YYINITIAL> {
  {IDENTIFIER} {
          appendCurrentFragment();
          if (isOverLimit()) return YYEOF;
      }
  {BASIC_NUM} | {HEX_NUM} | {QUOTED_STR} | {DOUBLE_QUOTED_STR} | {DOLLAR_QUOTED_STR} {
          builder.append('?');
          if (isOverLimit()) return YYEOF;
      }
  {WHITESPACE} {
          builder.append(' ');
          if (isOverLimit()) return YYEOF;
      }
  .+ {
          appendCurrentFragment();
          if (isOverLimit()) return YYEOF;
      }
}
