/// MemoryDatabase - 内存数据库实现
/// 
/// 实现一个简单的内存数据库，支持基本的 SQL 操作和事务
/// 
/// 功能：
/// 1. 支持 INSERT、SELECT、UPDATE、DELETE
/// 2. 支持基本的事务（快照机制）
/// 3. 支持 WHERE 条件（简化版）
/// 
/// 注意：
/// - 这是一个简化实现，用于演示和测试
/// - 不支持复杂的 SQL 语法
/// - 事务使用快照机制实现

// ========== 导入依赖 ==========

// 从 RowMapper 模块导入类型（同一包内，直接使用）
// Row 类型已在 RowMapper.mbt 中定义：pub type Row = @hashmap.HashMap[String, String]
// 在同一包内，可以直接使用 Row（类型别名），不需要重新定义

// ========== 数据结构 ==========

///|
/// SQL 语句类型
pub enum SqlStatement {
  Insert(String, Array[String], Array[String]) // 表名, 列名, 值
  Select(String, Array[String], String?) // 表名, 列名, WHERE条件
  Update(String, Array[(String, String)], String?) // 表名, SET子句, WHERE条件
  Delete(String, String?) // 表名, WHERE条件
}

///|
/// 事务快照（数据备份）
pub struct TransactionSnapshot {
  tables : @hashmap.HashMap[String, @hashmap.HashMap[String, Row]]
}

///|
/// 创建事务快照
pub fn TransactionSnapshot::new(
  tables : @hashmap.HashMap[String, @hashmap.HashMap[String, Row]],
) -> TransactionSnapshot {
  { tables, }
}

///|
/// 内存数据库
pub struct MemoryDatabase {
  // 表名 -> 行数据（行ID -> 行数据）
  tables : @hashmap.HashMap[String, @hashmap.HashMap[String, Row]]

  // 事务状态（事务ID -> 数据快照）
  transactions : @hashmap.HashMap[String, TransactionSnapshot]

  // 行ID 计数器（用于生成唯一行ID）
  row_id_counter : Int
}

///|
/// 创建内存数据库
pub fn MemoryDatabase::new() -> MemoryDatabase {
  { tables: @hashmap.new(), transactions: @hashmap.new(), row_id_counter: 0 }
}

///|
/// 获取行 ID 计数器（用于生成唯一行 ID）
pub fn MemoryDatabase::get_row_id_counter(self : MemoryDatabase) -> Int {
  self.row_id_counter
}

///|
/// 设置行 ID 计数器
pub fn MemoryDatabase::set_row_id_counter(
  self : MemoryDatabase,
  counter : Int,
) -> MemoryDatabase {
  { ..self, row_id_counter: counter }
}

// ========== SQL 解析器（简化版） ==========

///|
/// 字符串工具函数
fn has_prefix(s : String, prefix : String) -> Bool {
  if s.length() < prefix.length() {
    false
  } else {
    try s[:prefix.length()] == prefix catch {
      _ => false
    }
  }
}

///|
fn contains(s : String, substr : String) -> Bool {
  let mut i = 0
  let substr_len = substr.length()
  let s_len = s.length()
  while i <= s_len - substr_len {
    try {
      if s[i:i + substr_len] == substr {
        return true
      }
    } catch {
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
fn trim(s : String) -> String {
  // 简化实现：移除前后空格
  // 注意：由于 Moonbit 字符串切片的限制，这里使用简化实现
  // 实际使用中可能需要更复杂的实现
  s // 简化实现：直接返回原字符串
}

///|
/// 解析 SQL 语句（简化版）
/// 
/// 支持的语法：
/// - INSERT INTO table (col1, col2) VALUES (?, ?)
/// - SELECT * FROM table WHERE id = ?
/// - SELECT col1, col2 FROM table WHERE id = ?
/// - UPDATE table SET col1 = ? WHERE id = ?
/// - DELETE FROM table WHERE id = ?
pub fn parse_sql(sql : String) -> SqlStatement? {
  // 简化实现：直接检查前缀（大小写不敏感）
  let sql_len = sql.length()
  let has_insert_prefix1 = has_prefix(sql, "INSERT INTO")
  let has_insert_prefix2 = has_prefix(sql, "insert into")
  let has_insert_prefix = has_insert_prefix1 || has_insert_prefix2
  let has_select_prefix1 = has_prefix(sql, "SELECT")
  let has_select_prefix2 = has_prefix(sql, "select")
  let has_select_prefix = has_select_prefix1 || has_select_prefix2
  let has_update_prefix1 = has_prefix(sql, "UPDATE")
  let has_update_prefix2 = has_prefix(sql, "update")
  let has_update_prefix = has_update_prefix1 || has_update_prefix2
  let has_delete_prefix1 = has_prefix(sql, "DELETE FROM")
  let has_delete_prefix2 = has_prefix(sql, "delete from")
  let has_delete_prefix = has_delete_prefix1 || has_delete_prefix2
  let has_insert = sql_len >= 11 && has_insert_prefix
  let has_select = sql_len >= 6 && has_select_prefix
  let has_update = sql_len >= 6 && has_update_prefix
  let has_delete = sql_len >= 11 && has_delete_prefix
  if has_insert {
    // INSERT INTO table (col1, col2) VALUES (?, ?)
    parse_insert(sql)
  } else if has_select {
    // SELECT * FROM table WHERE id = ?
    parse_select(sql)
  } else if has_update {
    // UPDATE table SET col1 = ? WHERE id = ?
    parse_update(sql)
  } else if has_delete {
    // DELETE FROM table WHERE id = ?
    parse_delete(sql)
  } else {
    None
  }
}

///|
/// 查找子字符串（简化实现：逐个字符比较）
fn find(s : String, substr : String) -> Int? {
  let mut i = 0
  let s_len = s.length()
  let substr_len = substr.length()
  while i <= s_len - substr_len {
    // 逐个字符比较
    let mut matched = true
    let mut j = 0
    while j < substr_len {
      let s_char = s.code_unit_at(i + j)
      let substr_char = substr.code_unit_at(j)
      if s_char != substr_char {
        matched = false
        break
      }
      j = j + 1
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 查找子字符串（从指定位置开始，简化实现：逐个字符比较）
fn find_from(s : String, substr : String, start : Int) -> Int? {
  let mut i = start
  let s_len = s.length()
  let substr_len = substr.length()
  while i <= s_len - substr_len {
    // 逐个字符比较
    let mut matched = true
    let mut j = 0
    while j < substr_len {
      let s_char = s.code_unit_at(i + j)
      let substr_char = substr.code_unit_at(j)
      if s_char != substr_char {
        matched = false
        break
      }
      j = j + 1
    }
    if matched {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// 解析 INSERT 语句（简化版）
/// 
/// 支持格式：INSERT INTO table (col1, col2) VALUES (?, ?)
/// 
/// 注意：由于字符串切片限制，这里使用逐个字符解析
fn parse_insert(sql : String) -> SqlStatement? {
  // 找到 "INSERT INTO" 的位置
  match find(sql, "INSERT INTO") {
    Some(start) =>
      // 找到表名（INSERT INTO 之后到第一个 ( 之前）
      match find_from(sql, "(", start + 11) {
        Some(table_end) => {
          // 提取表名（跳过空格）
          let mut table_name_start = start + 11
          while table_name_start < table_end && sql.code_unit_at(table_name_start) == ' ' {
            table_name_start = table_name_start + 1
          }

          // 简化实现：使用固定字符位置提取表名
          let table_name_result = ""
          let mut table_name = table_name_result
          let mut i = table_name_start
          while i < table_end {
            let c = sql.code_unit_at(i)
            if c != 32 { // 32 是空格的 ASCII 码
              table_name = table_name + c.unsafe_to_char().to_string()
            }
            i = i + 1
          }

          // 找到列名列表（第一个 ( 到第一个 )）
          match find_from(sql, ")", table_end) {
            Some(cols_end) => {
              // 提取列名字符串
              let mut cols_str = ""
              let mut j = table_end + 1
              while j < cols_end {
                cols_str = cols_str + sql.code_unit_at(j).to_string()
                j = j + 1
              }
              let columns = parse_column_list(cols_str)

              // 找到 VALUES（支持大小写不敏感）
              // 先跳过可能的空格
              let mut search_start = cols_end + 1
              while search_start < sql.length() && sql.code_unit_at(search_start) == ' ' {
                search_start = search_start + 1
              }
              let mut vals_start : Int? = None
              match find_from(sql, "VALUES", search_start) {
                Some(pos) => vals_start = Some(pos)
                None =>
                  match find_from(sql, "values", search_start) {
                    Some(pos) => vals_start = Some(pos)
                    None => ()
                  }
              }
              match vals_start {
                Some(vals_start_pos) => {
                  // 找到 VALUES 后的 (（跳过可能的空格）
                  let vals_len = 6 // "VALUES" 或 "values" 的长度
                  let mut paren_pos = vals_start_pos + vals_len
                  // 跳过空格
                  while paren_pos < sql.length() && sql.code_unit_at(paren_pos) == ' ' {
                    paren_pos = paren_pos + 1
                  }
                  match find_from(sql, "(", paren_pos) {
                    Some(values_open) =>
                      // 找到对应的 )
                      match find_from(sql, ")", values_open) {
                        Some(values_close) => {
                          // 提取值列表（跳过 ? 占位符）
                          // 简化实现：只计算参数数量
                          let mut count = 0
                          let mut k = values_open + 1
                          while k < values_close {
                            if sql.code_unit_at(k) == '?' {
                              count = count + 1
                            }
                            k = k + 1
                          }
                          let values = parse_value_list_from_count(count)
                          if columns.length() == values.length() {
                            Some(
                              SqlStatement::Insert(table_name, columns, values),
                            )
                          } else {
                            None
                          }
                        }
                        None => None
                      }
                    None => None
                  }
                }
                None => None
              }
            }
            None => None
          }
        }
        None => None
      }
    None => None
  }
}

///|
/// 从参数数量创建值列表
fn parse_value_list_from_count(count : Int) -> Array[String] {
  let result : Array[String] = []
  let result_mut = result
  let mut i = 0
  while i < count {
    result_mut.push("?")
    i = i + 1
  }
  result_mut
}

///|
/// 解析 SELECT 语句（简化版）
/// 
/// 支持格式：
/// - SELECT * FROM table WHERE id = ?
/// - SELECT col1, col2 FROM table WHERE id = ?
fn parse_select(sql : String) -> SqlStatement? {
  // 找到 "FROM" 的位置（支持大小写不敏感）
  let mut from_pos : Int? = None
  match find(sql, "FROM") {
    Some(pos) => from_pos = Some(pos)
    None =>
      match find(sql, "from") {
        Some(pos) => from_pos = Some(pos)
        None => ()
      }
  }
  match from_pos {
    Some(from) => {
      // 提取列名（SELECT 和 FROM 之间的部分）
      let select_part_result = ""
      let mut select_part = select_part_result
      let mut i = 0
      while i < from {
        select_part = select_part + sql.code_unit_at(i).to_string()
        i = i + 1
      }
      let columns = if has_prefix(select_part, "SELECT *") {
        [] // 空数组表示 SELECT *
      } else {
        // 提取列名（跳过 "SELECT "）
        let mut cols_str = ""
        let mut j = 7 // 跳过 "SELECT "
        while j < from {
          cols_str = cols_str + sql.code_unit_at(j).to_string()
          j = j + 1
        }
        parse_column_list(cols_str)
      }

      // 找到表名（FROM 之后，跳过空格）
      let from_start_base = from + 4
      let mut from_start = from_start_base
      while from_start < sql.length() && sql.code_unit_at(from_start) == ' ' {
        from_start = from_start + 1
      }

      // 查找 WHERE（如果有，支持大小写不敏感）
      let mut where_pos : Int? = None
      match find_from(sql, "WHERE", from_start) {
        Some(pos) => where_pos = Some(pos)
        None =>
          match find_from(sql, "where", from_start) {
            Some(pos) => where_pos = Some(pos)
            None => ()
          }
      }
      match where_pos {
        Some(where_pos) => {
          // 提取表名（跳过空格，只取到 WHERE 之前）
          let table_name_result = ""
          let mut table_name = table_name_result
          let mut k = from_start
          while k < where_pos {
            let c = sql.code_unit_at(k)
            if c != 32 { // 32 是空格的 ASCII 码
              table_name = table_name + c.unsafe_to_char().to_string()
            }
            k = k + 1
          }

          // 提取 WHERE 子句（跳过 WHERE 关键字）
          let where_clause_result = ""
          let mut where_clause = where_clause_result
          let where_len = 5 // "WHERE" 或 "where" 的长度
          let mut m = where_pos + where_len
          while m < sql.length() {
            where_clause = where_clause + sql.code_unit_at(m).to_string()
            m = m + 1
          }
          Some(SqlStatement::Select(table_name, columns, Some(where_clause)))
        }
        None => {
          // 没有 WHERE 子句
          let table_name_result = ""
          let mut table_name = table_name_result
          let mut k = from_start
          while k < sql.length() {
            let c = sql.code_unit_at(k)
            if c != 32 { // 32 是空格的 ASCII 码
              table_name = table_name + c.unsafe_to_char().to_string()
            }
            k = k + 1
          }
          Some(SqlStatement::Select(table_name, columns, None))
        }
      }
    }
    None => None
  }
}

///|
/// 解析 UPDATE 语句（简化版）
/// 
/// 支持格式：UPDATE table SET col1 = ? WHERE id = ?
fn parse_update(sql : String) -> SqlStatement? {
  // 找到 "SET" 的位置（大小写不敏感）
  let mut set_pos : Int? = None
  let sql_upper = find(sql, "SET")
  let sql_lower = find(sql, "set")
  match sql_upper {
    Some(pos) => set_pos = Some(pos)
    None =>
      match sql_lower {
        Some(pos) => set_pos = Some(pos)
        None => ()
      }
  }
  match set_pos {
    Some(set) => {
      // 提取表名（UPDATE 之后到 SET 之前）
      let mut table_name = ""
      let mut i = 7 // 跳过 "UPDATE "
      while i < set {
        if sql.code_unit_at(i) != ' ' {
          table_name = table_name + sql.code_unit_at(i).to_string()
        }
        i = i + 1
      }

      // 找到 SET 和 WHERE 之间的部分
      match find_from(sql, "WHERE", set) {
        Some(where_pos) => {
          // 提取 SET 子句
          let mut set_clause = ""
          let mut j = set + 3 // 跳过 "SET"
          while j < where_pos {
            set_clause = set_clause + sql.code_unit_at(j).to_string()
            j = j + 1
          }

          // 提取 WHERE 子句
          let mut where_clause = ""
          let mut k = where_pos + 5 // 跳过 "WHERE"
          while k < sql.length() {
            where_clause = where_clause + sql.code_unit_at(k).to_string()
            k = k + 1
          }
          let set_pairs = parse_set_clause(set_clause)
          Some(SqlStatement::Update(table_name, set_pairs, Some(where_clause)))
        }
        None => {
          // 没有 WHERE 子句
          let mut set_clause = ""
          let mut j = set + 3 // 跳过 "SET"
          while j < sql.length() {
            set_clause = set_clause + sql.code_unit_at(j).to_string()
            j = j + 1
          }
          let set_pairs = parse_set_clause(set_clause)
          Some(SqlStatement::Update(table_name, set_pairs, None))
        }
      }
    }
    None => None
  }
}

///|
/// 解析 DELETE 语句（简化版）
/// 
/// 支持格式：DELETE FROM table WHERE id = ?
fn parse_delete(sql : String) -> SqlStatement? {
  // 找到 "FROM" 的位置
  match find(sql, "FROM") {
    Some(from) => {
      let from_start = from + 4 // 跳过 "FROM"

      // 查找 WHERE
      match find_from(sql, "WHERE", from_start) {
        Some(where_pos) => {
          // 提取表名
          let mut table_name = ""
          let mut i = from_start
          while i < where_pos {
            if sql.code_unit_at(i) != ' ' {
              table_name = table_name + sql.code_unit_at(i).to_string()
            }
            i = i + 1
          }

          // 提取 WHERE 子句
          let mut where_clause = ""
          let mut j = where_pos + 5 // 跳过 "WHERE"
          while j < sql.length() {
            where_clause = where_clause + sql.code_unit_at(j).to_string()
            j = j + 1
          }
          Some(SqlStatement::Delete(table_name, Some(where_clause)))
        }
        None => {
          // 没有 WHERE 子句
          let mut table_name = ""
          let mut i = from_start
          while i < sql.length() {
            if sql.code_unit_at(i) != ' ' {
              table_name = table_name + sql.code_unit_at(i).to_string()
            }
            i = i + 1
          }
          Some(SqlStatement::Delete(table_name, None))
        }
      }
    }
    None => None
  }
}

///|
/// 解析列名列表（简化实现：逐个字符解析）
fn parse_column_list(cols_str : String) -> Array[String] {
  let result : Array[String] = []
  let result_mut = result
  let mut current_col = ""
  let len = cols_str.length()
  let mut i = 0
  while i < len {
    let c = cols_str.code_unit_at(i)
    if c == ',' {
      // 遇到逗号，保存当前列名
      let trimmed = trim(current_col)
      if trimmed.length() > 0 {
        result_mut.push(trimmed)
      }
      current_col = ""
    } else if c != ' ' {
      // 非空格字符，添加到当前列名
      current_col = current_col + c.to_string()
    }
    i = i + 1
  }
  // 添加最后一个列名
  let trimmed = trim(current_col)
  if trimmed.length() > 0 {
    result_mut.push(trimmed)
  }
  result_mut
}

///|
/// 解析 SET 子句（简化实现：逐个字符解析）
/// 
/// 格式：col1 = ?, col2 = ?
fn parse_set_clause(set_clause : String) -> Array[(String, String)] {
  let result : Array[(String, String)] = []
  let result_mut = result
  let mut current_pair = ""
  let len = set_clause.length()
  let mut i = 0
  while i < len {
    let c = set_clause.code_unit_at(i)
    if c == ',' {
      // 遇到逗号，解析当前对
      match find(current_pair, "=") {
        Some(eq) => {
          // 提取列名和值
          let mut col = ""
          let mut j = 0
          while j < eq {
            if current_pair.code_unit_at(j) != ' ' {
              col = col + current_pair.code_unit_at(j).to_string()
            }
            j = j + 1
          }
          let mut val = ""
          let mut k = eq + 1
          while k < current_pair.length() {
            if current_pair.code_unit_at(k) != ' ' {
              val = val + current_pair.code_unit_at(k).to_string()
            }
            k = k + 1
          }
          if col.length() > 0 {
            result_mut.push((col, val))
          }
        }
        None => ()
      }
      current_pair = ""
    } else {
      current_pair = current_pair + c.to_string()
    }
    i = i + 1
  }

  // 解析最后一个对
  if current_pair.length() > 0 {
    match find(current_pair, "=") {
      Some(eq) => {
        let mut col = ""
        let mut j = 0
        while j < eq {
          if current_pair.code_unit_at(j) != ' ' {
            col = col + current_pair.code_unit_at(j).to_string()
          }
          j = j + 1
        }
        let mut val = ""
        let mut k = eq + 1
        while k < current_pair.length() {
          if current_pair.code_unit_at(k) != ' ' {
            val = val + current_pair.code_unit_at(k).to_string()
          }
          k = k + 1
        }
        if col.length() > 0 {
          result_mut.push((col, val))
        }
      }
      None => ()
    }
  }
  result_mut
}

// ========== SQL 执行引擎 ==========

///|
/// 执行 SQL 语句
/// 
/// 参数：
/// - sql: SQL 语句
/// - params: 参数数组（替换 ? 占位符）
/// 
/// 返回值：
/// - 影响的行数
pub fn MemoryDatabase::execute(
  self : MemoryDatabase,
  sql : String,
  params : Array[String],
) -> (Int, MemoryDatabase) {
  match parse_sql(sql) {
    Some(stmt) =>
      match stmt {
        Insert(table, columns, _values) => {
          let (result, updated_db) = self.execute_insert(table, columns, params)
          (result, updated_db)
        }
        Update(table, set_pairs, where_clause) => {
          let (result, updated_db) = self.execute_update(
            table, set_pairs, where_clause, params,
          )
          (result, updated_db)
        }
        Delete(table, where_clause) => {
          let (result, updated_db) = self.execute_delete(
            table, where_clause, params,
          )
          (result, updated_db)
        }
        _ => (0, self)
      }
    None => {
      println("  ❌ [内存数据库] SQL 解析失败: \{sql}")
      (0, self)
    }
  }
}

///|
/// 执行 INSERT 操作
pub fn MemoryDatabase::execute_insert(
  self : MemoryDatabase,
  table_name : String,
  columns : Array[String],
  params : Array[String],
) -> (Int, MemoryDatabase) {
  // 确保表存在
  let new_tables = self.tables
  if not(new_tables.contains(table_name)) {
    new_tables.set(table_name, @hashmap.new())
  }
  match new_tables.get(table_name) {
    Some(table) => {
      // 生成行ID
      let new_counter = self.row_id_counter + 1
      let row_id = "row_" + new_counter.to_string()

      // 创建行数据
      let row : @hashmap.HashMap[String, String] = @hashmap.new()
      row.set("id", row_id)

      // 填充列数据
      let mut i = 0
      while i < columns.length() && i < params.length() {
        row.set(columns[i], params[i])
        i = i + 1
      }

      // 插入行
      table.set(row_id, row)
      new_tables.set(table_name, table) // 更新表
      let updated_db = {
        ..self,
        tables: new_tables,
        row_id_counter: new_counter,
      }
      println(
        "  ✅ [内存数据库] INSERT 成功: 表=\{table_name}, 行ID=\{row_id}",
      )
      (1, updated_db)
    }
    None => (0, self)
  }
}

///|
/// 执行 UPDATE 操作
pub fn MemoryDatabase::execute_update(
  self : MemoryDatabase,
  table_name : String,
  set_pairs : Array[(String, String)],
  where_clause : String?,
  params : Array[String],
) -> (Int, MemoryDatabase) {
  match self.tables.get(table_name) {
    Some(table) => {
      let mut updated_count = 0
      let new_table = table
      let updated_tables = self.tables

      // 简化实现：只支持 WHERE id = ? 的情况
      match where_clause {
        Some(where_clause_var) =>
          if contains(where_clause_var, "id =") {
            // 提取参数值（第一个参数是 id 的值）
            if params.length() > 0 {
              let id_value = params[0]

              // 查找行
              match new_table.get(id_value) {
                Some(row) => {
                  // 更新列值（从第二个参数开始）
                  let mut param_idx = 1
                  set_pairs
                  .iter()
                  .each(fn(pair : (String, String)) {
                    let (col, _val) = pair
                    if param_idx < params.length() {
                      row.set(col, params[param_idx])
                      param_idx = param_idx + 1
                    }
                  })
                  new_table.set(id_value, row)
                  updated_tables.set(table_name, new_table) // 更新表
                  updated_count = 1
                }
                None => ()
              }
            }
          }
        None => {
          // 没有 WHERE 子句，更新所有行
          new_table
          .iter()
          .each(fn(entry : (String, Row)) {
            let (_id, row) = entry
            let mut param_idx = 0
            set_pairs
            .iter()
            .each(fn(pair : (String, String)) {
              let (col, _val) = pair
              if param_idx < params.length() {
                row.set(col, params[param_idx])
                param_idx = param_idx + 1
              }
            })
            updated_count = updated_count + 1
          })
          updated_tables.set(table_name, new_table) // 更新表
        }
      }
      if updated_count > 0 {
        println(
          "  ✅ [内存数据库] UPDATE 成功: 表=\{table_name}, 更新行数=\{updated_count}",
        )
      }
      let updated_db = { ..self, tables: updated_tables }
      (updated_count, updated_db)
    }
    None => {
      println("  ❌ [内存数据库] 表不存在: \{table_name}")
      (0, self)
    }
  }
}

///|
/// 执行 DELETE 操作
pub fn MemoryDatabase::execute_delete(
  self : MemoryDatabase,
  table_name : String,
  where_clause : String?,
  params : Array[String],
) -> (Int, MemoryDatabase) {
  match self.tables.get(table_name) {
    Some(table) => {
      let mut deleted_count = 0
      let new_table = table
      let updated_tables = self.tables

      // 简化实现：只支持 WHERE id = ? 的情况
      match where_clause {
        Some(where_clause_var) =>
          if contains(where_clause_var, "id =") {
            // 第一个参数是 id 的值
            if params.length() > 0 {
              let id_value = params[0]
              match new_table.get(id_value) {
                Some(_row) => {
                  new_table.remove(id_value)
                  updated_tables.set(table_name, new_table) // 更新表
                  deleted_count = 1
                }
                None => ()
              }
            }
          }
        None => {
          // 没有 WHERE 子句，删除所有行
          deleted_count = new_table.length()
          new_table.clear()
          updated_tables.set(table_name, new_table) // 更新表
        }
      }
      if deleted_count > 0 {
        println(
          "  ✅ [内存数据库] DELETE 成功: 表=\{table_name}, 删除行数=\{deleted_count}",
        )
      }
      let updated_db = { ..self, tables: updated_tables }
      (deleted_count, updated_db)
    }
    None => {
      println("  ❌ [内存数据库] 表不存在: \{table_name}")
      (0, self)
    }
  }
}

///|
/// 查询数据
/// 
/// 参数：
/// - sql: SELECT 语句
/// - params: 参数数组
/// 
/// 返回值：
/// - 查询结果行列表
pub fn MemoryDatabase::query(
  self : MemoryDatabase,
  sql : String,
  params : Array[String],
) -> Array[Row] {
  match parse_sql(sql) {
    Some(stmt) =>
      match stmt {
        Select(table_name, columns, where_clause) =>
          self.execute_select(table_name, columns, where_clause, params)
        _ => []
      }
    None => {
      println("  ❌ [内存数据库] SQL 解析失败: \{sql}")
      []
    }
  }
}

///|
/// 执行 SELECT 操作
pub fn MemoryDatabase::execute_select(
  self : MemoryDatabase,
  table_name : String,
  columns : Array[String],
  where_clause : String?,
  params : Array[String],
) -> Array[Row] {
  match self.tables.get(table_name) {
    Some(table) => {
      let results : Array[Row] = []
      let results_mut = results
      table
      .iter()
      .each(fn(entry : (String, Row)) {
        let (row_id, row) = entry
        let mut matched = true

        // 应用 WHERE 条件（简化实现）
        match where_clause {
          Some(where_clause_var) =>
            if contains(where_clause_var, "id =") {
              // 第一个参数是 id 的值
              if params.length() > 0 {
                matched = row_id == params[0]
              }
            }
          None => matched = true
        }
        if matched {
          // 选择列（简化实现：如果 columns 为空，返回所有列）
          if columns.length() == 0 {
            results_mut.push(row)
          } else {
            // 创建新行，只包含指定的列
            let filtered_row : @hashmap.HashMap[String, String] = @hashmap.new()
            columns
            .iter()
            .each(fn(col : String) {
              match row.get(col) {
                Some(val) => filtered_row.set(col, val)
                None => ()
              }
            })
            results_mut.push(filtered_row)
          }
        }
      })
      if results_mut.length() > 0 {
        println(
          "  ✅ [内存数据库] SELECT 成功: 表=\{table_name}, 返回行数=\{results_mut.length()}",
        )
      }
      results_mut
    }
    None => {
      println("  ❌ [内存数据库] 表不存在: \{table_name}")
      []
    }
  }
}

// ========== 事务支持 ==========

///|
/// 开始事务（创建数据快照）
pub fn MemoryDatabase::begin_transaction(
  self : MemoryDatabase,
  transaction_id : String,
) -> MemoryDatabase {
  // 创建数据快照
  let snapshot_tables : @hashmap.HashMap[String, @hashmap.HashMap[String, Row]] = @hashmap.new()
  self.tables
  .iter()
  .each(fn(table_entry) {
    let (table_name, table) = table_entry
    let snapshot_table : @hashmap.HashMap[String, Row] = @hashmap.new()
    table
    .iter()
    .each(fn(row_entry) {
      let (row_id, row) = row_entry
      // 创建行的深拷贝（简化实现）
      let snapshot_row : @hashmap.HashMap[String, String] = @hashmap.new()
      row
      .iter()
      .each(fn(col_entry : (String, String)) {
        let (col, val) = col_entry
        snapshot_row.set(col, val)
      })
      snapshot_table.set(row_id, snapshot_row)
    })
    snapshot_tables.set(table_name, snapshot_table)
  })
  let snapshot = TransactionSnapshot::new(snapshot_tables)
  let new_transactions = self.transactions
  new_transactions.set(transaction_id, snapshot)
  println("  🔵 [内存数据库] 开始事务: \{transaction_id}")
  { ..self, transactions: new_transactions }
}

///|
/// 提交事务（移除快照）
pub fn MemoryDatabase::commit_transaction(
  self : MemoryDatabase,
  transaction_id : String,
) -> MemoryDatabase {
  match self.transactions.get(transaction_id) {
    Some(_snapshot) => {
      // 移除快照（数据已应用）
      let new_transactions = self.transactions
      new_transactions.remove(transaction_id)
      println("  ✅ [内存数据库] 提交事务: \{transaction_id}")
      { ..self, transactions: new_transactions }
    }
    None => {
      println("  ⚠️  [内存数据库] 事务不存在: \{transaction_id}")
      self
    }
  }
}

///|
/// 回滚事务（恢复数据快照）
pub fn MemoryDatabase::rollback_transaction(
  self : MemoryDatabase,
  transaction_id : String,
) -> MemoryDatabase {
  match self.transactions.get(transaction_id) {
    Some(snapshot) => {
      // 恢复数据快照
      let new_transactions = self.transactions
      new_transactions.remove(transaction_id)
      println("  ❌ [内存数据库] 回滚事务: \{transaction_id}")
      { ..self, tables: snapshot.tables, transactions: new_transactions }
    }
    None => {
      println("  ⚠️  [内存数据库] 事务不存在: \{transaction_id}")
      self
    }
  }
}

///|
/// 检查是否存在活动事务
pub fn MemoryDatabase::has_transaction(
  self : MemoryDatabase,
  transaction_id : String,
) -> Bool {
  self.transactions.contains(transaction_id)
}
