# frozen_string_literal: true

RSpec.describe QueryOptimizerClient::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.api_url).to eq('http://localhost:3000/api/v1')
      expect(config.enabled).to be false
      expect(config.timeout).to eq(30)
      expect(config.retries).to eq(3)
      expect(config.default_threshold).to eq(80)
      expect(config.batch_size).to eq(50)
      expect(config.rate_limit_retry).to be true
    end

    it "reads from environment variables" do
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_API_URL', anything).and_return('https://custom.api.com/v1')
      allow(ENV).to receive(:[]).with('QUERY_OPTIMIZER_API_KEY').and_return('env_key')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_ENABLED', 'false').and_return('true')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_TIMEOUT', '30').and_return('60')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_RETRIES', '3').and_return('5')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_THRESHOLD', '80').and_return('90')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_BATCH_SIZE', '50').and_return('100')
      allow(ENV).to receive(:fetch).with('QUERY_OPTIMIZER_RATE_LIMIT_RETRY', 'true').and_return('false')

      config = described_class.new

      expect(config.api_url).to eq('https://custom.api.com/v1')
      expect(config.api_key).to eq('env_key')
      expect(config.enabled).to be true
      expect(config.timeout).to eq(60)
      expect(config.retries).to eq(5)
      expect(config.default_threshold).to eq(90)
      expect(config.batch_size).to eq(100)
      expect(config.rate_limit_retry).to be false
    end
  end

  describe "#enabled?" do
    context "when enabled is true and api_key is present" do
      before do
        config.enabled = true
        config.api_key = "test_key"
      end

      it "returns true" do
        expect(config.enabled?).to be true
      end
    end

    context "when enabled is false" do
      before do
        config.enabled = false
        config.api_key = "test_key"
      end

      it "returns false" do
        expect(config.enabled?).to be false
      end
    end

    context "when api_key is blank" do
      before do
        config.enabled = true
        config.api_key = ""
      end

      it "returns false" do
        expect(config.enabled?).to be false
      end
    end

    context "when api_key is nil" do
      before do
        config.enabled = true
        config.api_key = nil
      end

      it "returns false" do
        expect(config.enabled?).to be false
      end
    end
  end

  describe "#valid?" do
    context "when api_key and api_url are present" do
      before do
        config.api_key = "test_key"
        config.api_url = "https://api.example.com/v1"
      end

      it "returns true" do
        expect(config.valid?).to be true
      end
    end

    context "when api_key is missing" do
      before do
        config.api_key = nil
        config.api_url = "https://api.example.com/v1"
      end

      it "returns false" do
        expect(config.valid?).to be false
      end
    end

    context "when api_url is missing" do
      before do
        config.api_key = "test_key"
        config.api_url = nil
      end

      it "returns false" do
        expect(config.valid?).to be false
      end
    end
  end

  describe "#validate!" do
    context "when configuration is valid" do
      before do
        config.api_key = "test_key"
        config.api_url = "https://api.example.com/v1"
      end

      it "does not raise an error" do
        expect { config.validate! }.not_to raise_error
      end
    end

    context "when api_key is missing" do
      before do
        config.api_key = nil
        config.api_url = "https://api.example.com/v1"
      end

      it "raises ValidationError" do
        expect { config.validate! }.to raise_error(QueryOptimizerClient::ValidationError, "API key is required")
      end
    end

    context "when api_url is missing" do
      before do
        config.api_key = "test_key"
        config.api_url = nil
      end

      it "raises ValidationError" do
        expect { config.validate! }.to raise_error(QueryOptimizerClient::ValidationError, "API URL is required")
      end
    end

    context "when api_url is invalid" do
      before do
        config.api_key = "test_key"
        config.api_url = "not_a_url"
      end

      it "raises ValidationError" do
        expect { config.validate! }.to raise_error(QueryOptimizerClient::ValidationError, "Invalid API URL format")
      end
    end
  end
end
