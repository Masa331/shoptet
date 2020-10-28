module Shoptet
  class Api
    class Error < StandardError
      attr_reader :additional_data

      def initialize message, additional_data = {}
        super(message)
        @additional_data = additional_data
      end
    end

    def self.shop_info token
      uri = 'https://api.myshoptet.com/api/eshop'
      headers = { 'Shoptet-Access-Token' => token,
                  'Content-Type' => 'application/vnd.shoptet.v1.0' }

      result = handle_errors ApiRequest.get(uri, headers), uri, headers

      result
    end

    def self.products token, page = 1
      uri = "https://api.myshoptet.com/api/products?page=#{page}"
      headers = { 'Shoptet-Access-Token' => token,
                  'Content-Type' => 'application/vnd.shoptet.v1.0' }

      handle_errors ApiRequest.get(uri, headers), uri, headers
    end

    def self.product token, guid
      uri = "https://api.myshoptet.com/api/products/#{guid}?include=variantParameters,images,allCategories"
      headers = { 'Shoptet-Access-Token' => token,
                  'Content-Type' => 'application/vnd.shoptet.v1.0' }

      handle_errors ApiRequest.get(uri, headers), uri, headers
    end

    def self.product_changes token, since, page = 1
      params = { from: since.iso8601, page: page }.to_param

      uri = "https://api.myshoptet.com/api/products/changes?#{params}"
      headers = { 'Shoptet-Access-Token' => token,
                  'Content-Type' => 'application/vnd.shoptet.v1.0' }

      handle_errors ApiRequest.get(uri, headers), uri, headers
    end

    def self.new_api_token oauth_token
      uri = Rails.application.credentials.shoptet[:oauth_api_token_url]
      headers = { 'Authorization' => "Bearer #{oauth_token}" }

      result = handle_errors ApiRequest.get(uri, headers), uri, headers

      result.fetch 'access_token'
    end

    private

    def self.handle_errors result, uri, headers
      if result['errors'] && result['errors'].any?
        if result['errors'].all? { |error| error['errorCode'] == 'invalid-token' }
          throw :invalid_api_token, 'invalid_token'
        elsif result['errors'].all? { |error| error['errorCode'] == 'expired-token' }
          throw :invalid_api_token, 'expired_token'
        else
          additional_data = {
            uri: uri,
            headers: scrub_sensitive_headers(headers)
          }

          raise ShoptetApiError.new result, additional_data
        end
      elsif result.key? 'error'
        additional_data = {
          uri: uri,
          headers: scrub_sensitive_headers(headers)
        }

        raise ShoptetApiError.new result, additional_data
      else
        result
      end
    end

    def self.scrub_sensitive_headers headers
      scrubbed = {}

      if headers.key? 'Shoptet-Access-Token'
        token = headers['Shoptet-Access-Token']
        scrubbed['Shoptet-Access-Token'] = "#{token[0..20]}..."
      end

      if headers.key? 'Authorization'
        token = headers['Authorization']
        scrubbed['Authorization'] = "#{token[0..20]}..."
      end

      headers.merge scrubbed
    end
  end
end
