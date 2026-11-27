require 'rspec'
require 'cloud_controller/security/admin_token_network_policy'

RSpec.describe VCAP::CloudController::Security::AdminTokenNetworkPolicy do
  subject(:policy) { described_class.new(options, nginx_socket: '/private/cloud_controller.sock') }

  let(:options) { { enabled: true, allowed_cidrs: ['192.0.2.0/24', '2001:db8::/32'], trusted_proxies: ['10.0.0.0/24'] } }
  let(:token) { { 'scope' => ['cloud_controller.admin'] } }
  let(:env) { { 'REMOTE_ADDR' => '192.0.2.1' } }

  %w[uaa.admin cloud_controller.admin cloud_controller.admin_read_only cloud_controller.global_auditor zones.tenant.admin zones.*.admin].each do |scope|
    it "protects #{scope} in scopes and authorities" do
      expect(policy).not_to be_allowed({ 'scope' => [scope] }, { 'REMOTE_ADDR' => '198.51.100.1' })
      expect(policy).not_to be_allowed({ 'scope' => ['openid'], 'authorities' => [scope] }, { 'REMOTE_ADDR' => '198.51.100.1' })
    end
  end

  %w[192.0.2.0 192.0.2.255 2001:db8::1 ::ffff:192.0.2.10].each do |address|
    it "accepts allowed numeric address #{address}" do
      expect(policy).to be_allowed(token, { 'REMOTE_ADDR' => address })
    end
  end

  ['192.0.3.0', '2001:db9::1', 'localhost', '127.1', '192.0.2.1/32', '[2001:db8::1]', 'fe80::1%lo0', '', nil].each do |address|
    it "fails closed for outside or malformed address #{address.inspect}" do
      expect(policy).not_to be_allowed(token, { 'REMOTE_ADDR' => address })
    end
  end

  ['localhost', '127.1', '192.0.2.1/33', '2001:db8::/129', '192.0.2.1/', '192.0.2.1/-1',
   '192.0.2.1/255.255.255.0', '192.0.2.1/24/1', ' 192.0.2.1', '::ffff:192.0.2.1/120', ''].each do |cidr|
    it "rejects invalid configuration #{cidr.inspect} even when disabled" do
      expect { described_class.new({ enabled: false, allowed_cidrs: [cidr] }) }.to raise_error(ArgumentError)
      expect { described_class.new({ enabled: false, trusted_proxies: [cidr] }) }.to raise_error(ArgumentError)
    end
  end

  it 'does not trust forwarded or real-IP headers on direct requests, including loopback TCP' do
    spoofed = { 'REMOTE_ADDR' => '127.0.0.1', 'HTTP_X_REAL_IP' => '192.0.2.1', 'HTTP_X_FORWARDED_FOR' => '192.0.2.1' }
    expect(policy).not_to be_allowed(token, spoofed)
  end

  it 'uses the actual TCP socket peer rather than an overridden Rack address' do
    socket = double(:socket, local_address: Addrinfo.tcp('127.0.0.1', 3000), remote_address: Addrinfo.tcp('198.51.100.1', 5000))
    expect(policy).not_to be_allowed(token, env.merge('puma.socket' => socket))
  end

  it 'trusts the overwritten Nginx peer only on the configured Unix socket' do
    socket = double(:socket, local_address: Addrinfo.unix('/private/cloud_controller.sock'))
    request = { 'puma.socket' => socket, 'HTTP_X_REAL_IP' => '10.0.0.1',
                'HTTP_X_FORWARDED_FOR' => '198.51.100.10, 192.0.2.1, 10.0.0.1' }
    expect(policy).to be_allowed(token, request)
    request['HTTP_X_FORWARDED_FOR'] = '192.0.2.1, 198.51.100.10, 10.0.0.1'
    expect(policy).not_to be_allowed(token, request)
    request['HTTP_X_REAL_IP'] = '198.51.100.10'
    expect(policy).not_to be_allowed(token, request)
  end

  it 'does not accept headers on a different Unix socket' do
    socket = double(:socket, local_address: Addrinfo.unix('/other.sock'), remote_address: Addrinfo.unix('/client.sock'))
    expect(policy).not_to be_allowed(token, env.merge('puma.socket' => socket, 'HTTP_X_REAL_IP' => '192.0.2.1'))
  end

  ['192.0.2.1, garbage', '192.0.2.1,', '', '10.0.0.1, 10.0.0.2'].each do |forwarded|
    it "fails closed on unresolved trusted-proxy chain #{forwarded.inspect}" do
      expect(policy).not_to be_allowed(token, { 'REMOTE_ADDR' => '10.0.0.1', 'HTTP_X_FORWARDED_FOR' => forwarded })
    end
  end

  it 'bounds forwarded-chain parsing' do
    expect(policy).not_to be_allowed(token, { 'REMOTE_ADDR' => '10.0.0.1', 'HTTP_X_FORWARDED_FOR' => (['192.0.2.1'] * 65).join(',') })
  end

  it 'preserves ordinary tokens and disabled policy, but enabled empty allowlists deny administrative tokens' do
    expect(policy).to be_allowed({ 'scope' => ['openid', 'zones.read', 'not.uaa.admin'] }, {})
    expect(described_class.new).to be_allowed(token, {})
    expect(described_class.new({ enabled: true, allowed_cidrs: [] })).not_to be_allowed(token, env)
  end

  it 'supports additional exact protected scope names without replacing built-ins' do
    additional = described_class.new({ enabled: true, additional_protected_scopes: ['clients.write'] })
    expect(additional).not_to be_allowed({ 'scope' => ['clients.write'] }, env)
    expect(additional).not_to be_allowed(token, env)
  end
end
