require 'yaml'

module YamlUtils
  # #truncate is a way to limit the size of a yaml-able string, by removing the longest arrays from the end
  # @candidate - a string, doesn't have to be yaml-encodable
  def self.truncate(candidate, max_size)
    # warn("QQQ: candidate.size:#{candidate.size}, max_size:#{max_size}")
    return candidate if candidate.size < max_size

    begin
      @full_object = YAML.safe_load(candidate)
      @max_size = max_size
      return YAML.dump(truncate_object(@full_object))
    rescue Psych::SyntaxError
      # Assume it doesn't matter how this gets truncated
      return candidate[0...max_size]
    end
  end

  def self.truncate_array(object)
    # warn("QQQ: truncate_array: object:#{object}, max_size:#{@max_size}, start size: #{object.size}")
    while !object.empty? && YAML.dump(@full_object).size > @max_size
      # warn("  QQQ: current array size: #{object.size}, yaml dump:#{YAML.dump(object)}, yaml size:#{YAML.dump(object).size}")
      # warn("  QQQ: current full object yaml size:#{YAML.dump(@full_object).size}")
      # warn("  QQQ: underlying yaml dump:#{YAML.dump(@full_object).inspect}")
      last_object = object[-1]
      case last_object
      when Array
        truncate_array(last_object)
      when Hash
        truncate_hash(last_object)
      else
        object.delete_at(-1)
      end
    end
    # warn("  QQQ: finally, current array size: #{object.size}, yaml dump:#{YAML.dump(object)}, yaml size:#{YAML.dump(object).size}")

    object
  end

  def self.truncate_hash(object)
    # debugger
    keys_by_size = object.keys.map { |k| [YAML.dump(object[k]).size, k] }.sort { |a, b| a[0] <=> b[0] }.map { |_, k| k }
    keys_by_size.reverse.each do |k|
      break if YAML.dump(@full_object).size <= @max_size
      temp_obj = object.delete(k)
      next if YAML.dump(@full_object).size > @max_size
      # Reinsert the deleted object and start picking at it
      object[k] = temp_obj
      object[k] = truncate_object(object[k])
    end
    object
  end

  def self.truncate_object(object)
    case object
    when Array
      truncate_array(object)
    when Hash
      truncate_hash(object)
    when String
      object[0...@max_size]
    else
      object
    end
  end
end
