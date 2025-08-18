class QueryDataValidator
  include ActiveModel::Validations
  
  attr_accessor :sql, :duration_ms
  
  validates :sql, presence: { message: "SQL query is required" }
  validates :sql, length: { 
    minimum: 10, 
    maximum: 10000, 
    message: "SQL query must be between 10 and 10,000 characters" 
  }
  validates :duration_ms, numericality: { 
    greater_than_or_equal_to: 0, 
    less_than: 3600000,  # 1 hour max
    message: "Duration must be between 0 and 3,600,000 milliseconds"
  }, allow_nil: true
  
  def initialize(query_data)
    @sql = query_data[:sql] || query_data['sql']
    @duration_ms = query_data[:duration_ms] || query_data['duration_ms']
  end
  
  def self.validate_queries(queries_data)
    errors = []

    unless queries_data.is_a?(Array)
      return ["Queries must be an array"]
    end

    if queries_data.empty?
      return ["At least one query is required"]
    end

    if queries_data.length > 100
      return ["Maximum 100 queries allowed per request"]
    end
    
    queries_data.each_with_index do |query_data, index|
      validator = new(query_data)
      unless validator.valid?
        validator.errors.messages.each do |attribute, messages|
          messages.each do |message|
            errors << "Query #{index + 1}: #{message}"
          end
        end
      end
      
      # Additional SQL validation
      sql = query_data[:sql] || query_data['sql']
      if sql.present?
        sql_errors = validate_sql_content(sql, index + 1)
        errors.concat(sql_errors)
      end
    end
    
    errors
  end
  
  private
  
  def self.validate_sql_content(sql, index)
    errors = []
    
    # Check for dangerous SQL patterns
    dangerous_patterns = [
      /\bDROP\s+/i,
      /\bDELETE\s+FROM\s+(?!.*WHERE)/i,  # DELETE without WHERE
      /\bTRUNCATE\s+/i,
      /\bALTER\s+/i,
      /\bCREATE\s+/i,
      /\bINSERT\s+INTO\s+(?!.*VALUES)/i,  # INSERT without VALUES
      /\bUPDATE\s+(?!.*WHERE)/i,  # UPDATE without WHERE
      /\bGRANT\s+/i,
      /\bREVOKE\s+/i
    ]
    
    dangerous_patterns.each do |pattern|
      if sql.match?(pattern)
        errors << "Query #{index}: Contains potentially dangerous SQL pattern"
        break
      end
    end
    
    # Check for basic SQL structure
    unless sql.match?(/\b(SELECT|INSERT|UPDATE|DELETE)\b/i)
      errors << "Query #{index}: Must be a valid SQL statement (SELECT, INSERT, UPDATE, or DELETE)"
    end
    
    # Check for excessive complexity
    if sql.scan(/\bSELECT\b/i).length > 5
      errors << "Query #{index}: Query appears to be too complex (too many subqueries)"
    end
    
    errors
  end
end
