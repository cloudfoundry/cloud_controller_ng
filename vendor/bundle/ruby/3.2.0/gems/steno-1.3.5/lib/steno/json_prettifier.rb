require 'digest/md5'
require 'set'
require 'yajl'

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
  ]

  MIN_COL_WIDTH = 14

  class ParseError < StandardError
  end

  def initialize(excluded_fields = [])
    @time_format = '%Y-%m-%d %H:%M:%S.%6N'
    @excluded_fields = Set.new(excluded_fields)
    @max_src_len = MIN_COL_WIDTH
  end

  def prettify_line(line)
    begin
      json_record = Yajl::Parser.parse(line)
    rescue Yajl::ParseError => e
      raise ParseError, e.to_s
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
      pred_meth = :"check_#{field_name}"
      if respond_to?(pred_meth, true)
        exists = send(pred_meth, record)
      elsif record.respond_to?(:has_key?)
        exists = record.has_key?(field_name)
      else
        msg = "Expected the record to be a hash, but received: #{record.class}."
        raise ParseError, msg
      end

      fields << if exists
                  send(:"format_#{field_name}", record)
                else
                  '-'
                end
    end

    fields.join(' ') + "\n"
  end

  def format_timestamp(record)
    Time.at(record['timestamp']).strftime(@time_format)
  end

  def format_source(record)
    @max_src_len = [@max_src_len, record['source'].length].max
    record['source'].ljust(@max_src_len)
  end

  def format_process_id(record)
    format('pid=%-5s', record['process_id'])
  end

  def format_thread_id(record)
    format('tid=%s', shortid(record['thread_id']))
  end

  def format_fiber_id(record)
    format('fid=%s', shortid(record['fiber_id']))
  end

  def check_location(record)
    %w[file lineno method].reduce(true) { |ok, k| ok && record.has_key?(k) }
  end

  def format_location(record)
    parts = record['file'].split('/')

    trimmed_filename = nil
    trimmed_filename = if parts.size == 1
                         parts[0]
                       else
                         parts.slice(-2, 2).join('/')
                       end

    format('%s/%s:%s', trimmed_filename, record['method'], record['lineno'])
  end

  def check_data(record)
    record['data'].is_a?(Hash)
  end

  def format_data(record)
    record['data'].map { |k, v| "#{k}=#{v}" }.join(',')
  end

  def format_log_level(record)
    format('%7s', record['log_level'].upcase)
  end

  def format_message(record)
    format('-- %s', record['message'])
  end

  def shortid(data)
    return '-' if data.nil?

    digest = Digest::MD5.hexdigest(data.to_s)
    digest[0, 4]
  end
end
