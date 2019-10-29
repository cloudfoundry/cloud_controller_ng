require 'yaml'

module YamlUtils
  # #truncate is a way to limit the size of a yaml-able string, by removing the longest arrays from the end
  # @candidate - a string, doesn't have to be yaml-encodable
  def self.truncate(candidate, max_size)
    return candidate if candidate.size < max_size

    begin
      @full_object = YAML.safe_load(candidate)
      @max_size = max_size
      return YAML.dump(truncate_object(@full_object))
    rescue Psych::SyntaxError
      # Assume it doesn't matter how this gets truncated, as it isn't valid yaml to begin with
      return candidate[0...max_size]
    end
  end

  def self.truncate_array(object)
    while object.size > 0 && YAML.dump(@full_object).size > @max_size
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
    object
  end

  def self.truncate_hash(object)
    keys_by_size = object.keys.map { |k| [YAML.dump(object[k]).size, k] }.sort { |a, b| a[0] <=> b[0] }.map { |_, k| k }
    keys_by_size.reverse.each do |k|
      break if YAML.dump(@full_object).size <= @max_size

      part = object.delete(k)
      next if YAML.dump(@full_object).size > @max_size

      # Reinsert the deleted part and start picking at it
      object[k] = part
      object[k] = truncate_object(part)
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
