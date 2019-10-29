require 'yaml'

module YamlUtils
  # #truncate is a way to limit the size of a yaml-able string, by removing the longest arrays from the end
  # @candidate - a string, doesn't have to be yaml-encodable
  def self.truncate(candidate, max_size)
    return candidate if candidate.size < max_size

    begin
      return YAML.dump(truncate_object(YAML.safe_load(candidate), max_size))
    rescue Psych::SyntaxError
      # Assume it doesn't matter how this gets truncated
      return candidate[0...max_size]
    end
  end

  def self.truncate_array(object, max_size)
    while !object.empty? && YAML.dump(object).size > max_size
      last_object = object[-1]
      case last_object
      when Array
        truncate_array(last_object, max_size)
      when Hash
        truncate_hash(last_object, max_size)
      else
        object.delete_at(-1)
      end
    end
    object
  end

  def self.truncate_hash(object, max_size)
    # debugger
    keys_by_size = object.keys.map { |k| [YAML.dump(object[k]).size, k] }.sort { |a, b| a[0] <=> b[0] }.map { |_, k| k }
    processed_size = 0
    truncate_rest = false
    keys_by_size.each do |k|
      if truncate_rest
        # no more room for larger keys
        object.delete(k)
        next
      end
      item_size = YAML.dump(object[k]).size
      if processed_size + item_size > max_size
        truncate_object(object[k], max_size - processed_size)
        truncate_rest = true
      else
        processed_size += item_size
      end
    end
    object
  end

  def self.truncate_object(object, max_size)
    case object
    when Array
      truncate_array(object, max_size)
    when Hash
      truncate_hash(object, max_size)
    when String
      object[0...max_size]
    else
      object
    end
  end
end
