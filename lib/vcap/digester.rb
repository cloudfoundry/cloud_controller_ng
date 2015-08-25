class Digester
  ALGORITHM = Digest::SHA1
  TYPE = :hexdigest

  def initialize(algorithm: ALGORITHM, type: TYPE)
    @algorithm = algorithm
    @type = type
  end

  def digest(bits)
    algorithm.send(type, bits)
  end

  def digest_path(path)
    digest_file(File.new(path))
  end

  def digest_file(file)
    algorithm.file(file).send(type)
  end

  private

  attr_reader :algorithm, :type
end
