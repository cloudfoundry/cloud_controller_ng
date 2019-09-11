require 'rails_helper'

RSpec.describe ErrorsController, type: :controller do
  describe '#not_found' do
    it 'returns an error' do
      get :not_found

      expect(response.status).to eq(404)
      expect(parsed_body['errors'].first['title']).to eq('CF-NotFound')
    end
  end

  describe '#internal_error' do
    before do
      @request.env.merge!('action_dispatch.exception' => StandardError.new('sad things'))
      allow_any_instance_of(ErrorPresenter).to receive(:raise_500?).and_return(false)
    end

    it 'returns the error from the request env in action_dispatch.exception' do
      get :internal_error

      expect(response.status).to eq(500)
      expect(response).to have_error_message('An unknown error occurred.')
    end
  end

  describe '#bad_request' do
    it 'returns an error' do
      get :bad_request

      expect(response.status).to eq(400)
      expect(parsed_body['errors'].first['title']).to eq('CF-InvalidRequest')
    end
  end
end
