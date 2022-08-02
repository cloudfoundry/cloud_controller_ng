RSpec.shared_examples_for 'endpoint exempts from rate limiting' do |header_suffix=''|
  it 'exempts them from rate limiting' do
    allow(ActionDispatch::Request).to receive(:new).and_return(fake_request)
    _, response_headers, _ = middleware.call(env)
    expect(request_counter).not_to have_received(:get)
    expect(request_counter).not_to have_received(:increment)
    expect(response_headers["X-RateLimit-Limit#{header_suffix}"]).to be_nil
    expect(response_headers["X-RateLimit-Remaining#{header_suffix}"]).to be_nil
    expect(response_headers["X-RateLimit-Reset#{header_suffix}"]).to be_nil
  end
end
