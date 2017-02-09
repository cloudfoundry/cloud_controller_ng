module LinkHelpers
  include VCAP::CloudController

  def link_prefix
    "#{scheme}://#{host}"
  end

  private

  def scheme
    TestConfig.config[:external_protocol]
  end

  def host
    TestConfig.config[:external_domain]
  end
end
