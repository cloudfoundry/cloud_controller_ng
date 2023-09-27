RSpec.shared_examples_for 'exempted from rate limiting' do |header_suffix=''|
  it 'exempts them from rate limiting' do
    allow(ActionDispatch::Request).to receive(:new).and_return(fake_request) if defined?(fake_request)
    _, response_headers, = middleware.call(env)
    expect(expiring_request_counter).not_to have_received(:increment)
    expect(response_headers["X-RateLimit-Limit#{header_suffix}"]).to be_nil
    expect(response_headers["X-RateLimit-Remaining#{header_suffix}"]).to be_nil
    expect(response_headers["X-RateLimit-Reset#{header_suffix}"]).to be_nil
  end
end
