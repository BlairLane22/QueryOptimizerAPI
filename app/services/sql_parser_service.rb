class SqlParserService
  attr_reader :sql_query, :parsed_query, :parse_tree

  def initialize(sql_query)
    @sql_query = sql_query.strip
    @parsed_query = nil
    @parse_tree = nil
    parse_query
  end

  def self.parse(sql_query)
    new(sql_query)
  end

  # Extract the main table being queried
  def primary_table
    return nil unless parsed_query

    case query_type.downcase
    when 'select'
      extract_from_table
    when 'insert'
      extract_insert_table
    when 'update'
      extract_update_table
    when 'delete'
      extract_delete_table
    else
      nil
    end
  end

  # Get all tables referenced in the query
  def all_tables
    return [] unless parsed_query

    tables = []
    
    # Extract from FROM clauses
    tables.concat(extract_from_tables)
    
    # Extract from JOIN clauses
    tables.concat(extract_join_tables)
    
    # Extract from subqueries
    tables.concat(extract_subquery_tables)
    
    tables.uniq.compact
  end

  # Extract WHERE clause conditions
  def where_conditions
    return [] unless parsed_query

    conditions = []
    stmt = first_statement

    if stmt&.select_stmt&.where_clause
      extract_where_conditions_recursive(stmt.select_stmt.where_clause, conditions)
    elsif stmt&.update_stmt&.where_clause
      extract_where_conditions_recursive(stmt.update_stmt.where_clause, conditions)
    elsif stmt&.delete_stmt&.where_clause
      extract_where_conditions_recursive(stmt.delete_stmt.where_clause, conditions)
    end

    conditions
  end

  # Extract columns used in WHERE clauses
  def where_columns
    where_conditions.map { |condition| condition[:column] }.compact.uniq
  end

  # Extract JOIN conditions
  def join_conditions
    return [] unless parsed_query

    joins = []
    extract_join_conditions_recursive(parse_tree, joins)
    joins
  end

  # Determine query type (SELECT, INSERT, UPDATE, DELETE)
  def query_type
    return nil unless parsed_query

    stmt = first_statement
    return nil unless stmt

    if stmt.select_stmt
      'SELECT'
    elsif stmt.insert_stmt
      'INSERT'
    elsif stmt.update_stmt
      'UPDATE'
    elsif stmt.delete_stmt
      'DELETE'
    else
      'UNKNOWN'
    end
  end

  # Check if query has potential for N+1 pattern
  def potential_n_plus_one?
    return false unless query_type == 'SELECT'

    # Look for single-row lookups by ID or foreign key
    where_conditions.any? do |condition|
      column = condition[:column]
      next false unless column

      # Match patterns like: id, user_id, posts.id, table.column_id
      id_pattern = column.match?(/\bid\b|_id$/i)

      id_pattern &&
      condition[:operator] == '=' &&
      (condition[:value_type] == 'param' || condition[:value_type] == 'integer')
    end
  end

  # Extract ORDER BY columns
  def order_by_columns
    return [] unless parsed_query && query_type == 'SELECT'

    columns = []

    # Use regex to extract ORDER BY columns
    if sql_query.match?(/ORDER\s+BY/i)
      # Extract everything after ORDER BY
      order_part = sql_query.split(/ORDER\s+BY/i)[1]
      return [] unless order_part

      # Remove everything after LIMIT, OFFSET, or end of string
      order_clause = order_part.split(/\s+(?:LIMIT|OFFSET|;)/i)[0].strip

      # Split by comma and extract column names
      order_clause.split(',').each do |item|
        # Remove ASC/DESC and whitespace, extract column name
        column = item.strip.gsub(/\s+(ASC|DESC)\s*$/i, '').strip
        # Handle table.column format
        column = column.split('.').last if column.include?('.')
        # Remove any remaining whitespace or quotes
        column = column.gsub(/["`']/, '').strip
        columns << column unless column.empty?
      end
    end

    columns.uniq
  end

  # Check if query uses indexes (basic heuristic)
  def likely_uses_index?
    # Simple heuristic: queries with WHERE on id columns likely use indexes
    where_columns.any? { |col| col.match?(/(_id|\.id)$/i) }
  end

  # Generate a normalized query signature for similarity detection
  def query_signature
    normalized = sql_query.gsub(/\$\d+/, '?')             # Replace parameter placeholders first
                          .gsub(/\b\d+\b/, '?')           # Replace numbers
                          .gsub(/'[^']*'/, '?')           # Replace string literals
                          .gsub(/\s+/, ' ')               # Normalize whitespace
                          .strip
                          .downcase

    Digest::SHA256.hexdigest(normalized)
  end

  # Check if query is valid
  def valid?
    !parsed_query.nil?
  end

  # Get parsing errors
  def errors
    @errors ||= []
  end

  private

  def first_statement
    return nil unless parsed_query&.tree&.stmts&.first
    parsed_query.tree.stmts.first.stmt
  end

  def parse_query
    begin
      @parsed_query = PgQuery.parse(sql_query)
      @parse_tree = @parsed_query
      @errors = []
    rescue PgQuery::ParseError => e
      @errors = [e.message]
      @parsed_query = nil
      @parse_tree = nil
    rescue => e
      @errors = ["Unexpected parsing error: #{e.message}"]
      @parsed_query = nil
      @parse_tree = nil
    end
  end

  def extract_from_table
    stmt = first_statement
    return nil unless stmt&.select_stmt&.from_clause&.first

    range_var = stmt.select_stmt.from_clause.first.range_var
    range_var&.relname
  end

  def extract_insert_table
    stmt = first_statement
    stmt&.insert_stmt&.relation&.relname
  end

  def extract_update_table
    stmt = first_statement
    stmt&.update_stmt&.relation&.relname
  end

  def extract_delete_table
    stmt = first_statement
    stmt&.delete_stmt&.relation&.relname
  end

  def extract_from_tables
    tables = []
    stmt = first_statement
    return tables unless stmt&.select_stmt&.from_clause

    stmt.select_stmt.from_clause.each do |item|
      if item.range_var
        tables << item.range_var.relname
      end
    end

    tables
  end

  def extract_join_tables
    # This would need more complex parsing for JOIN clauses
    # For now, return empty array - can be enhanced
    []
  end

  def extract_subquery_tables
    # This would need recursive parsing for subqueries
    # For now, return empty array - can be enhanced
    []
  end

  def extract_where_conditions_recursive(node, conditions)
    return unless node

    if node.respond_to?(:a_expr) && node.a_expr
      condition = parse_a_expr(node.a_expr)
      conditions << condition if condition
    elsif node.respond_to?(:bool_expr) && node.bool_expr
      # Handle AND/OR expressions
      node.bool_expr.args&.each do |arg|
        extract_where_conditions_recursive(arg, conditions)
      end
    end

    # Recursively search through the node structure
    if node.respond_to?(:each)
      node.each do |item|
        extract_where_conditions_recursive(item, conditions)
      end
    elsif node.class.name.start_with?('PgQuery::')
      # For PgQuery objects, iterate through their attributes
      node.instance_variables.each do |var|
        value = node.instance_variable_get(var)
        extract_where_conditions_recursive(value, conditions)
      end
    end
  end

  def parse_a_expr(expr)
    return nil unless expr.kind == :AEXPR_OP

    left = expr.lexpr
    right = expr.rexpr
    operator = expr.name&.first&.string&.sval

    column = extract_column_ref(left)
    value_info = extract_value_info(right)

    {
      column: column,
      operator: operator,
      value: value_info[:value],
      value_type: value_info[:type]
    }
  end

  def extract_column_ref(node)
    return nil unless node&.column_ref

    fields = node.column_ref.fields
    return nil unless fields

    # Handle table.column or just column
    if fields.length == 2
      table = fields[0]&.string&.sval
      column = fields[1]&.string&.sval
      "#{table}.#{column}"
    elsif fields.length == 1
      fields[0]&.string&.sval
    end
  end

  def extract_value_info(node)
    if node&.a_const
      const = node.a_const
      if const.isnull
        { value: nil, type: 'null' }
      elsif const.ival
        { value: const.ival.ival, type: 'integer' }
      elsif const.sval
        { value: const.sval.sval, type: 'string' }
      elsif const.boolval
        { value: const.boolval.boolval, type: 'boolean' }
      else
        { value: const.to_s, type: 'unknown' }
      end
    elsif node&.param_ref
      { value: "$#{node.param_ref.number}", type: 'param' }
    else
      { value: node.to_s, type: 'expression' }
    end
  end

  def extract_join_conditions_recursive(node, joins)
    # Implementation for JOIN condition extraction
    # This is complex and would need detailed parsing
    # For now, placeholder
  end

  def extract_order_by_recursive(node, columns)
    return unless node

    stmt = first_statement
    return unless stmt&.select_stmt&.sort_clause

    stmt.select_stmt.sort_clause.each do |sort_item|
      if sort_item.node&.column_ref
        column_ref = extract_column_ref(sort_item.node)
        columns << column_ref if column_ref
      end
    end
  end
end
