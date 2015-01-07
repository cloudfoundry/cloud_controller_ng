class File
  def hexdigest
    Digest::SHA1.file(path).hexdigest
  end
end
