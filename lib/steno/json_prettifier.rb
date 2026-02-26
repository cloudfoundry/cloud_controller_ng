require 'digest/md5'
require 'oj'

module Steno
end

class Steno::JsonPrettifier
  FIELD_ORDER = %w[
    timestamp
    source
    process_id
    thread_id
    fiber_id
    location
    data
    log_level
    message
  ].freeze

  MIN_COL_WIDTH = 14

  class ParseError < StandardError
  end

  def initialize(excluded_fields=[])
    @time_format = '%Y-%m-%d %H:%M:%S.%6N'
    @excluded_fields = Set.new(excluded_fields)
    @max_src_len = MIN_COL_WIDTH
  end

  def prettify_line(line)
    begin
      json_record = Oj.load(line)
    rescue StandardError => e
      raise ParseError.new(e.to_s)
    end

    format_record(json_record)
  end

  protected

  def format_record(record)
    record ||= {}
    fields = []

    FIELD_ORDER.each do |field_name|
      next if @excluded_fields.include?(field_name)

      exists = nil
      pred_meth = :"#{field_name}?"
      if respond_to?(pred_meth, true)
        exists = send(pred_meth, record)
      elsif record.respond_to?(:key?)
        exists = record.key?(field_name)
      else
        msg = "Expected the record to be a hash, but received: #{record.class}."
        raise ParseError.new(msg)
      end

      fields << if exists
                  send(:"format_#{field_name}", record)
                else
                  '-'
                end
    end

    "#{fields.join(' ')}\n"
  end

  def format_timestamp(record)
    Time.at(record['timestamp']).strftime(@time_format)
  end

  def format_source(record)
    @max_src_len = [@max_src_len, record['source'].length].max
    record['source'].ljust(@max_src_len)
  end

  def format_process_id(record)
    sprintf('pid=%-5s', record['process_id'])
  end

  def format_thread_id(record)
    sprintf('tid=%s', shortid(record['thread_id']))
  end

  def format_fiber_id(record)
    sprintf('fid=%s', shortid(record['fiber_id']))
  end

  def location?(record)
    %w[file lineno method].reduce(true) { |ok, k| ok && record.key?(k) }
  end

  def format_location(record)
    parts = record['file'].split('/')

    trimmed_filename = if parts.size == 1
                         parts[0]
                       else
                         parts.slice(-2, 2).join('/')
                       end

    "#{trimmed_filename}/#{record['method']}:#{record['lineno']}"
  end

  def data?(record)
    record['data'].is_a?(Hash)
  end

  def format_data(record)
    record['data'].map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def format_log_level(record)
    sprintf('%7s', record['log_level'].upcase)
  end

  def format_message(record)
    sprintf('-- %s', record['message'])
  end

  def shortid(data)
    return '-' if data.nil?

    digest = Digest::MD5.hexdigest(data.to_s)
    digest[0, 4]
  end
end
