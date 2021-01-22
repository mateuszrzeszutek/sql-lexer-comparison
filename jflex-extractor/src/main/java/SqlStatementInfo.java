/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */


import java.util.Objects;

public final class SqlStatementInfo {
  private final String fullStatement;
  private final String operation;
  private final String table;

  public SqlStatementInfo(
      String fullStatement, String operation, String table) {
    this.fullStatement = fullStatement;
    this.operation = operation;
    this.table = table;
  }

  public String getFullStatement() {
    return fullStatement;
  }

  public String getOperation() {
    return operation;
  }

  public String getTable() {
    return table;
  }

  @Override
  public boolean equals(Object obj) {
    if (obj == this) {
      return true;
    }
    if (!(obj instanceof SqlStatementInfo)) {
      return false;
    }
    SqlStatementInfo other = (SqlStatementInfo) obj;
    return Objects.equals(fullStatement, other.fullStatement)
        && Objects.equals(operation, other.operation)
        && Objects.equals(table, other.table);
  }

  @Override
  public int hashCode() {
    return Objects.hash(fullStatement, operation, table);
  }

  @Override
  public String toString() {
    return "SqlStatementInfo{" +
            "operation='" + operation + '\'' +
            ", table='" + table + '\'' +
            '}';
  }
}
