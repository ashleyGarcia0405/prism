# app/services/dataset_ingestor.rb
require "csv"

class DatasetIngestor
  MAX_BYTES = 10 * 1024 * 1024 # 10 MB

  IngestResult = Struct.new(:row_count, :columns, keyword_init: true)

  def initialize(dataset:, io:, filename:)
    @dataset  = dataset
    @io       = io
    @filename = filename
    @conn     = ActiveRecord::Base.connection
  end

  def call
    bytes = safe_size(@io)
    raise ArgumentError, "File too large (max #{MAX_BYTES} bytes)" if bytes > MAX_BYTES

    headers = peek_headers
    raise ArgumentError, "CSV must have a header row" if headers.blank?

    # Ensure we have a valid physical table name
    @dataset.table_name ||= default_table_name
    @dataset.save! if @dataset.changed?

    norm_headers = normalize_headers(headers)
    sample_rows  = sample_first_n(200)
    type_map     = infer_types(sample_rows: sample_rows)

    sql_columns = norm_headers.map { |h| { "name" => h, "sql_type" => pg_type_for(type_map[h]) } }

    ActiveRecord::Base.transaction do
      create_table!(norm_headers, sql_columns)
      inserted = bulk_insert!(norm_headers, sql_columns)
      @dataset.update!(
        original_filename: @filename,
        row_count: inserted,
        columns: sql_columns
      )
      IngestResult.new(row_count: inserted, columns: sql_columns)
    end
  end

  private

  def default_table_name
    # ds_<org>_<id>_<slug>, safe for Postgres identifiers
    slug = @dataset.name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_+|_+$/, "")
    slug = "dataset" if slug.empty?
    "ds_#{@dataset.organization_id}_#{@dataset.id}_#{slug}"[0, 63] # keep under 63 chars
  end

  private

  def safe_size(io)
    return io.size if io.respond_to?(:size)
    pos = io.pos if io.respond_to?(:pos)
    data = io.read
    io.rewind if io.respond_to?(:rewind)
    data.bytesize
  ensure
    io.seek(pos) if pos && io.respond_to?(:seek)
  end

  # ----  CSV reads ----
  def peek_headers
    rewind
    csv = CSV.new(@io, headers: true, encoding: "bom|utf-8", return_headers: false)
    first_row = csv.shift
    headers = first_row&.headers || csv.headers

    # Fallback: if still nil, try reading one more row (handles weird blank header lines)
    if headers.nil?
      first_row = csv.shift
      headers = first_row&.headers
    end

    rewind
    sanitize_headers(headers)
  rescue EOFError
    rewind
    []
  end





  def sanitize_headers(headers)
    return [] if headers.nil?
    headers.map { |h| h.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "").strip }
  end

  def rewind
    @io.rewind if @io.respond_to?(:rewind)
  end

  # ---------- schema inference ----------
  def normalize_headers(headers)
    seen = {}
    headers.map do |h|
      base = h.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/^_+|_+$/, "")
      base = "col" if base.blank?
      name = base
      i = 1
      while seen[name]
        i += 1
        name = "#{base}_#{i}"
      end
      seen[name] = true
      name
    end
  end

  def sample_first_n(n)
    rewind
    rows = []
    CSV.new(@io, headers: true, encoding: "bom|utf-8").each do |row|
      rows << row
      break if rows.size >= n
    end
    rewind
    rows
  end

  def infer_types(sample_rows:)
    headers = sample_rows.first&.headers || []
    headers = normalize_headers(headers)

    # Start as :boolean so we can promote to :integer → :float → :text as needed.
    # If a column has "true/false/1/0" it stays boolean; otherwise it promotes.
    type_map = headers.index_with { :boolean }

    sample_rows.each do |row|
      headers.each_with_index do |h, idx|
        val = row[idx]
        next if val.nil? || val.to_s.strip.empty?
        type_map[h] = widen(type_map[h], classify(val))
      end
    end
    type_map
  end

  def classify(val)
    s = val.to_s.strip
    return :boolean if %w[true false t f yes no 1 0].include?(s.downcase)
    return :integer if integer?(s)
    return :float   if float?(s)
    :text
  end

  def widen(current, observed)
    order = { boolean: 0, integer: 1, float: 2, text: 3 }
    order[observed] > order[current] ? observed : current
  end

  def integer?(s)
    Integer(s)
    true
  rescue ArgumentError, TypeError
    false
  end

  def float?(s)
    Float(s)
    true
  rescue ArgumentError, TypeError
    false
  end

  def pg_type_for(sym)
    case sym
    when :boolean then "boolean"
    when :integer then "integer"
    when :float   then "double precision"
    else               "text"
    end
  end

  # ---------- DDL + DML ----------
  def create_table!(headers, sql_columns)
    drop_if_exists!
    cols_sql = sql_columns.map { |c| "#{quote_col(c['name'])} #{c['sql_type']}" }.join(", ")
    @conn.execute("CREATE TABLE #{quote_table} (#{cols_sql});")
  end

  def drop_if_exists!
    @conn.execute("DROP TABLE IF EXISTS #{quote_table};")
  end

  def bulk_insert!(headers, sql_columns)
    inserted = 0
    CSV.new(@io, headers: true, encoding: "bom|utf-8").each do |row|
      values = headers.map.with_index { |_h, idx| cast_value(row[idx], sql_columns[idx]["sql_type"]) }
      cols = headers.map { |h| quote_col(h) }.join(", ")
      vals = values.map { |v| @conn.quote(v) }.join(", ")
      @conn.execute("INSERT INTO #{quote_table} (#{cols}) VALUES (#{vals})")
      inserted += 1
    end
    inserted
  end

  def cast_value(v, sql_type)
    return nil if v.nil? || v.to_s.strip.empty?
    case sql_type
    when "boolean"          then %w[true t yes 1].include?(v.to_s.strip.downcase)
    when "integer"          then v.to_i
    when "double precision" then v.to_f
    else                         v.to_s
    end
  end

  def quote_table; @conn.quote_table_name(@dataset.table_name); end
  def quote_col(name); @conn.quote_column_name(name); end
end
