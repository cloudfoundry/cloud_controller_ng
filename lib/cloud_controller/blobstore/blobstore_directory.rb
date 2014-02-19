class BlobstoreDirectory
  def initialize(connection, key)
    @connection = connection
    @key = key
  end

  def create
    @connection.directories.create(key: @key, public: false)
  end

  def exists?
    @connection.directories.get(@key, max_keys: 0)
  end
end
