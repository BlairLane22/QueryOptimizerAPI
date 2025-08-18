require 'rails_helper'

RSpec.describe Api::V1::ApiKeysController, type: :controller do
  describe 'POST #create' do
    context 'with valid app name' do
      it 'creates a new API key' do
        post :create, params: { app_name: 'Test Application' }, as: :json

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(json_response['data']['app_name']).to eq('Test Application')
        expect(json_response['data']['api_key']).to be_present
        expect(json_response['data']['created_at']).to be_present
        expect(json_response['message']).to include('created successfully')
      end

      it 'creates an AppProfile record' do
        expect {
          post :create, params: { app_name: 'Test Application' }, as: :json
        }.to change(AppProfile, :count).by(1)
        
        app_profile = AppProfile.last
        expect(app_profile.name).to eq('Test Application')
        expect(app_profile.api_key_digest).to be_present
      end
    end

    context 'with invalid app name' do
      it 'returns error for missing app name' do
        post :create, params: {}, as: :json

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('Missing required parameter')
      end

      it 'returns error for blank app name' do
        post :create, params: { app_name: '' }, as: :json

        expect(response).to have_http_status(:bad_request)

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('App name is required')
      end

      it 'returns error for app name too short' do
        post :create, params: { app_name: 'AB' }, as: :json

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('between 3 and 100 characters')
      end

      it 'returns error for app name too long' do
        long_name = 'A' * 101
        post :create, params: { app_name: long_name }, as: :json

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to include('between 3 and 100 characters')
      end

      it 'returns error for duplicate app name' do
        create(:app_profile, name: 'Existing App')
        
        post :create, params: { app_name: 'Existing App' }, as: :json

        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
        expect(json_response['error']).to eq('App name already exists')
      end
    end
  end

  describe 'GET #show' do
    let(:app_profile) { create(:app_profile) }
    let(:api_key) { 'test_api_key_123' }

    before do
      app_profile.update!(api_key_digest: BCrypt::Password.create(api_key))
      allow_any_instance_of(Api::V1::BaseController).to receive(:authenticate_api_key) do |controller|
        controller.instance_variable_set(:@current_app_profile, app_profile)
      end
      request.headers['X-API-Key'] = api_key
    end

    it 'returns current API key information' do
      # Create some query analyses to test the count
      create_list(:query_analysis, 3, app_profile: app_profile)
      
      get :show, as: :json

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['app_name']).to eq(app_profile.name)
      expect(json_response['data']['created_at']).to be_present
      expect(json_response['data']['last_used']).to be_present
      expect(json_response['data']['total_queries']).to eq(3)
    end
  end

  describe 'POST #regenerate' do
    let(:app_profile) { create(:app_profile) }
    let(:api_key) { 'test_api_key_123' }

    before do
      app_profile.update!(api_key_digest: BCrypt::Password.create(api_key))
      allow_any_instance_of(Api::V1::BaseController).to receive(:authenticate_api_key) do |controller|
        controller.instance_variable_set(:@current_app_profile, app_profile)
      end
      request.headers['X-API-Key'] = api_key
    end

    it 'regenerates the API key' do
      old_digest = app_profile.api_key_digest
      
      post :regenerate, as: :json

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['app_name']).to eq(app_profile.name)
      expect(json_response['data']['api_key']).to be_present
      expect(json_response['data']['regenerated_at']).to be_present
      expect(json_response['message']).to include('regenerated successfully')
      
      # Verify the digest changed
      app_profile.reload
      expect(app_profile.api_key_digest).not_to eq(old_digest)
    end
  end

  describe 'DELETE #destroy' do
    let(:app_profile) { create(:app_profile) }
    let(:api_key) { 'test_api_key_123' }

    before do
      app_profile.update!(api_key_digest: BCrypt::Password.create(api_key))
      allow_any_instance_of(Api::V1::BaseController).to receive(:authenticate_api_key) do |controller|
        controller.instance_variable_set(:@current_app_profile, app_profile)
      end
      request.headers['X-API-Key'] = api_key
    end

    it 'deletes the API key and app profile' do
      app_name = app_profile.name
      
      expect {
        delete :destroy, as: :json
      }.to change(AppProfile, :count).by(-1)

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['data']['app_name']).to eq(app_name)
      expect(json_response['data']['deleted_at']).to be_present
      expect(json_response['message']).to include('deleted successfully')
    end

    it 'deletes associated query analyses' do
      create_list(:query_analysis, 3, app_profile: app_profile)
      
      expect {
        delete :destroy, as: :json
      }.to change(QueryAnalysis, :count).by(-3)
    end
  end

  describe 'authentication requirements' do
    context 'for protected endpoints' do
      it 'requires authentication for show' do
        get :show, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'requires authentication for regenerate' do
        post :regenerate, as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'requires authentication for destroy' do
        delete :destroy, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'for create endpoint' do
      it 'does not require authentication for create' do
        post :create, params: { app_name: 'Test App' }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
