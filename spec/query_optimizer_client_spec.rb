# frozen_string_literal: true

RSpec.describe QueryOptimizerClient do
  it "has a version number" do
    expect(QueryOptimizerClient::VERSION).not_to be nil
  end

  describe ".configure" do
    it "yields configuration" do
      expect { |b| QueryOptimizerClient.configure(&b) }.to yield_with_args(QueryOptimizerClient.configuration)
    end

    it "allows setting configuration options" do
      QueryOptimizerClient.configure do |config|
        config.api_url = "https://example.com/api/v1"
        config.api_key = "test_key"
        config.enabled = true
      end

      expect(QueryOptimizerClient.configuration.api_url).to eq("https://example.com/api/v1")
      expect(QueryOptimizerClient.configuration.api_key).to eq("test_key")
      expect(QueryOptimizerClient.configuration.enabled).to be true
    end
  end

  describe ".enabled?" do
    context "when enabled and api_key is present" do
      before do
        QueryOptimizerClient.configure do |config|
          config.enabled = true
          config.api_key = "test_key"
        end
      end

      it "returns true" do
        expect(QueryOptimizerClient.enabled?).to be true
      end
    end

    context "when disabled" do
      before do
        QueryOptimizerClient.configure do |config|
          config.enabled = false
          config.api_key = "test_key"
        end
      end

      it "returns false" do
        expect(QueryOptimizerClient.enabled?).to be false
      end
    end

    context "when api_key is missing" do
      before do
        QueryOptimizerClient.configure do |config|
          config.enabled = true
          config.api_key = nil
        end
      end

      it "returns false" do
        expect(QueryOptimizerClient.enabled?).to be false
      end
    end
  end

  describe ".analyze_queries" do
    let(:queries) do
      [
        { sql: "SELECT * FROM users", duration_ms: 50 },
        { sql: "SELECT * FROM posts", duration_ms: 100 }
      ]
    end

    before do
      QueryOptimizerClient.configure do |config|
        config.api_url = "https://api.example.com/v1"
        config.api_key = "test_key"
        config.enabled = true
      end
    end

    it "delegates to client" do
      client = instance_double(QueryOptimizerClient::Client)
      allow(QueryOptimizerClient).to receive(:client).and_return(client)
      
      expect(client).to receive(:analyze_queries).with(queries)
      
      QueryOptimizerClient.analyze_queries(queries)
    end
  end

  describe ".analyze_for_ci" do
    let(:queries) do
      [{ sql: "SELECT * FROM users", duration_ms: 50 }]
    end

    before do
      QueryOptimizerClient.configure do |config|
        config.api_url = "https://api.example.com/v1"
        config.api_key = "test_key"
        config.enabled = true
      end
    end

    it "delegates to client with default threshold" do
      client = instance_double(QueryOptimizerClient::Client)
      allow(QueryOptimizerClient).to receive(:client).and_return(client)
      
      expect(client).to receive(:analyze_for_ci).with(queries, threshold: 80)
      
      QueryOptimizerClient.analyze_for_ci(queries)
    end

    it "delegates to client with custom threshold" do
      client = instance_double(QueryOptimizerClient::Client)
      allow(QueryOptimizerClient).to receive(:client).and_return(client)
      
      expect(client).to receive(:analyze_for_ci).with(queries, threshold: 90)
      
      QueryOptimizerClient.analyze_for_ci(queries, threshold: 90)
    end
  end

  describe ".reset!" do
    before do
      QueryOptimizerClient.configure do |config|
        config.api_key = "test_key"
      end
      
      # Access client to create it
      QueryOptimizerClient.client
    end

    it "resets configuration and client" do
      QueryOptimizerClient.reset!
      
      expect(QueryOptimizerClient.configuration.api_key).to be_nil
      expect(QueryOptimizerClient.instance_variable_get(:@client)).to be_nil
    end
  end
end
