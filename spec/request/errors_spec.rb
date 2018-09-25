require 'spec_helper'

RSpec.describe 'Errors' do
  let(:user) { make_user }
  let(:user_headers) { headers_for(user, email: 'some_email@example.com', user_name: 'Mr. Freeze') }

  # Rails 5.0.x makes it difficult to test redirections after JSON parsing errors
  # directly since these occur deep in the parsing middleware.
  #
  # We are now testing via a request so that the required middlewares are present
  describe 'invalid request json' do
    let(:user) { VCAP::CloudController::User.make }
    let(:user_header) { headers_for(user, email: Sham.email, user_name: 'some-username') }

    it 'it returns a MessageParseError' do
      expect {
        patch '/v3/apps/some-guid/features/ssh', '}}-invalid', user_header
      }.to output("Error occurred while parsing request parameters.\nContents:\n\n}}-invalid\n").to_stderr

      expect(last_response.status).to eq(400)
      expect(last_response.body).to include('Request invalid due to parse error: invalid request body')
    end
  end
end
