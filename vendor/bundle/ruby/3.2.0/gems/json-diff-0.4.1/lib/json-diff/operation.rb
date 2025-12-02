module JsonDiff

  # Convert a list of strings or numbers to an RFC6901 JSON pointer.
  # http://tools.ietf.org/html/rfc6901
  def self.json_pointer(path)
    return "" if path == []

    escaped_path = path.map do |key|
      if key.is_a?(String)
        key.gsub('~', '~0')
           .gsub('/', '~1')
      else
        key.to_s
      end
    end.join('/')

    "/#{escaped_path}"
  end

  # Add a key to a JSON pointer.
  def self.extend_json_pointer(pointer, key)
    if pointer == ''
      json_pointer([key])
    else
      pointer + json_pointer([key])
    end
  end

  def self.replace(path, before, after)
    if before != nil
      {'op' => 'replace', 'path' => path, 'was' => before, 'value' => after}
    else
      {'op' => 'replace', 'path' => path, 'value' => after}
    end
  end

  def self.add(path, value)
    {'op' => 'add', 'path' => path, 'value' => value}
  end

  def self.remove(path, value)
    if value != nil
      {'op' => 'remove', 'path' => path, 'was' => value}
    else
      {'op' => 'remove', 'path' => path}
    end
  end

  def self.move(source, target)
    {'op' => 'move', 'from' => source, 'path' => target}
  end

end
