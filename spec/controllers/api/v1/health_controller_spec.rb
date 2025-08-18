require 'rails_helper'

RSpec.describe Api::V1::HealthController, type: :controller do
  describe 'GET #show' do
    context 'when all services are healthy' do
      before do
        # Mock successful service checks
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:valid?).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:query_type).and_return('SELECT')
        allow_any_instance_of(SqlParserService).to receive(:primary_table).and_return('users')
        allow(NPlusOneDetectorService).to receive(:detect).and_return([])
        allow(SlowQueryAnalyzerService).to receive(:analyze).and_return([])
        allow(MissingIndexDetectorService).to receive(:detect).and_return([])
      end

      it 'returns healthy status' do
        get :show

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('ok')
        expect(json_response).to have_key('timestamp')
        expect(json_response).to have_key('version')
        expect(json_response).to have_key('services')
      end

      it 'checks all required services' do
        get :show

        json_response = JSON.parse(response.body)
        services = json_response['services']
        
        expect(services).to have_key('database')
        expect(services).to have_key('sql_parser')
        expect(services).to have_key('analysis_services')
        
        expect(services['database']).to eq('ok')
        expect(services['sql_parser']).to eq('ok')
        expect(services['analysis_services']).to eq('ok')
      end

      it 'includes version information' do
        get :show

        json_response = JSON.parse(response.body)
        expect(json_response['version']).to eq('1.0.0')
      end

      it 'includes timestamp' do
        get :show

        json_response = JSON.parse(response.body)
        expect(json_response['timestamp']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end

    context 'when database is unhealthy' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('Database error'))
        allow_any_instance_of(SqlParserService).to receive(:valid?).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:query_type).and_return('SELECT')
        allow_any_instance_of(SqlParserService).to receive(:primary_table).and_return('users')
        allow(NPlusOneDetectorService).to receive(:detect).and_return([])
        allow(SlowQueryAnalyzerService).to receive(:analyze).and_return([])
        allow(MissingIndexDetectorService).to receive(:detect).and_return([])
      end

      it 'returns degraded status' do
        get :show

        expect(response).to have_http_status(:service_unavailable)
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('degraded')
        expect(json_response['services']['database']).to eq('error')
      end
    end

    context 'when SQL parser is unhealthy' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:valid?).and_return(false)
        allow(NPlusOneDetectorService).to receive(:detect).and_return([])
        allow(SlowQueryAnalyzerService).to receive(:analyze).and_return([])
        allow(MissingIndexDetectorService).to receive(:detect).and_return([])
      end

      it 'returns degraded status' do
        get :show

        expect(response).to have_http_status(:service_unavailable)
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('degraded')
        expect(json_response['services']['sql_parser']).to eq('error')
      end
    end

    context 'when analysis services are unhealthy' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:valid?).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:query_type).and_return('SELECT')
        allow_any_instance_of(SqlParserService).to receive(:primary_table).and_return('users')
        allow(NPlusOneDetectorService).to receive(:detect).and_raise(StandardError.new('Analysis error'))
      end

      it 'returns degraded status' do
        get :show

        expect(response).to have_http_status(:service_unavailable)
        
        json_response = JSON.parse(response.body)
        expect(json_response['status']).to eq('degraded')
        expect(json_response['services']['analysis_services']).to eq('error')
      end
    end

    context 'without authentication' do
      it 'allows health checks without API key' do
        # Don't set any authentication headers
        get :show

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('status')
      end
    end

    context 'with partial service failures' do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        allow_any_instance_of(SqlParserService).to receive(:valid?).and_return(false)
        allow(NPlusOneDetectorService).to receive(:detect).and_return([])
        allow(SlowQueryAnalyzerService).to receive(:analyze).and_return([])
        allow(MissingIndexDetectorService).to receive(:detect).and_return([])
      end

      it 'shows mixed service status' do
        get :show

        json_response = JSON.parse(response.body)
        services = json_response['services']
        
        expect(services['database']).to eq('ok')
        expect(services['sql_parser']).to eq('error')
        expect(services['analysis_services']).to eq('ok')
        expect(json_response['status']).to eq('degraded')
      end
    end
  end

  describe 'service check methods' do
    let(:controller) { described_class.new }

    describe '#check_database' do
      it 'returns ok when database is accessible' do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_return(true)
        
        result = controller.send(:check_database)
        expect(result).to eq('ok')
      end

      it 'returns error when database is not accessible' do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(StandardError.new('DB error'))
        
        result = controller.send(:check_database)
        expect(result).to eq('error')
      end
    end

    describe '#check_sql_parser' do
      it 'returns ok when SQL parser works correctly' do
        parser = instance_double(SqlParserService)
        allow(SqlParserService).to receive(:new).and_return(parser)
        allow(parser).to receive(:valid?).and_return(true)
        allow(parser).to receive(:query_type).and_return('SELECT')
        allow(parser).to receive(:primary_table).and_return('users')
        
        result = controller.send(:check_sql_parser)
        expect(result).to eq('ok')
      end

      it 'returns error when SQL parser fails' do
        allow(SqlParserService).to receive(:new).and_raise(StandardError.new('Parser error'))
        
        result = controller.send(:check_sql_parser)
        expect(result).to eq('error')
      end
    end

    describe '#check_analysis_services' do
      it 'returns ok when all analysis services work' do
        allow(NPlusOneDetectorService).to receive(:detect).and_return([])
        allow(SlowQueryAnalyzerService).to receive(:analyze).and_return([])
        allow(MissingIndexDetectorService).to receive(:detect).and_return([])
        
        result = controller.send(:check_analysis_services)
        expect(result).to eq('ok')
      end

      it 'returns error when analysis services fail' do
        allow(NPlusOneDetectorService).to receive(:detect).and_raise(StandardError.new('Service error'))
        
        result = controller.send(:check_analysis_services)
        expect(result).to eq('error')
      end
    end
  end
end
