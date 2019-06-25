class UaaTokenCache
  TokenValue = Struct.new(:token, :expires_at)

  @tokens = {}

  def self.get_token(client_id)
    token_value = @tokens[client_id]
    return unless token_value

    token_value.token if token_value.expires_at.nil? || Time.now < token_value.expires_at
  end

  def self.set_token(client_id, token, expires_in: nil)
    @tokens[client_id] = TokenValue.new(token, expires_in ? expires_in.seconds.from_now : nil)
  end

  def self.clear_token(client_id)
    @tokens.delete(client_id)
  end

  def self.clear!
    @tokens = {}
  end
end
