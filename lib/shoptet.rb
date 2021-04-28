require 'delegate'
require_relative 'shoptet/request'
require_relative 'shoptet/api_enumerator'

class Shoptet
  class Error < StandardError; end
  class AddonSuspended < StandardError; end
  class AddonNotInstalled < StandardError; end
  class InvalidTokenNoRights < StandardError; end
  class EmptyResponse < StandardError; end
  class MaxPageReached < StandardError; end
  class StockNotFound < StandardError; end

  EXPIRED_TOKEN_CODE = 'expired-token'
  INVALID_TOKEN_CODE = 'invalid-token'
  ADDON_NOT_INSTALLED = 'Addon installation is not approved.'

  ON_TOKEN_ERROR = -> (api) do
    api.api_token = api.new_api_token
  end

  def self.version
    '0.0.25'
  end

  def self.ar_on_token_error(model)
    -> (api) do
      model.with_lock do
        model.reload

        if model.api_token != api.api_token
          api.api_token = model.api_token
        else
          new_token = api.new_api_token
          api.api_token = new_token
          model.api_token = new_token
          model.save!
        end
      end
    end
  end

  def self.install url, redirect_url, client_id, client_secret, code
    data = {
      'redirect_uri' => redirect_url,
      'client_id' => client_id,
      'client_secret' => client_secret,
      'code' => code,
      'grant_type' => 'authorization_code',
      'scope' => 'api'
    }

    Shoptet::Request.post(url, data)
  end

  def self.login_token url, code, client_id, client_secret, redirect_url
    data = {
      code: code,
      grant_type: 'authorization_code',
      client_id: client_id,
      client_secret: client_secret,
      redirect_uri: redirect_url,
      scope: 'basic_eshop'
    }

    Shoptet::Request.post(url, data)
  end

  def self.basic_eshop url, access_token
    Shoptet::Request.get(url, { 'Authorization' => "Bearer #{access_token}" })
  end

  attr_accessor :api_token

  def initialize oauth_url:, oauth_token:, shop_url:, client_id:, api_token: nil, on_token_error: nil
    @oauth_url = oauth_url
    @oauth_token = oauth_token
    @shop_url = shop_url
    @client_id = client_id
    @api_token = api_token
    @on_token_error = on_token_error || ON_TOKEN_ERROR
  end

  def endpoints api_params = {}
    enumerize('https://api.myshoptet.com/api/system/endpoints', api_params)
  end

  def endpoint_approved? endpoint
    @approved_endpoints ||= endpoints

    @approved_endpoints.any? { _1['endpoint'] == endpoint }
  end

  def endpoints_approved? *endpoints_to_check
    endpoints_to_check.all? { endpoint_approved? _1 }
  end

  def authorize_url redirect_url, state
    query = {
      client_id: @client_id,
      state: state,
      scope: 'basic_eshop',
      response_type: 'code',
      redirect_uri: redirect_url
    }.to_query

    URI("#{@shop_url}action/OAuthServer/authorize?#{query}")
  end

  def shop_info api_params = {}
    result = request('https://api.myshoptet.com/api/eshop', api_params)
    result['data']
  end

  def design_info api_params = {}
    result = request('https://api.myshoptet.com/api/eshop/design', api_params)

    result['data']
  end

  def stocks api_params = {}
    enumerize('https://api.myshoptet.com/api/stocks', api_params)
  end

  def products api_params = {}
    enumerize("https://api.myshoptet.com/api/products", api_params)
  end

  def supplies warehouse_id, api_params = {}
    enumerize("https://api.myshoptet.com/api/stocks/#{warehouse_id}/supplies", api_params)
  end

  def stocks_movements warehouse_id, api_params = {}
    enumerize("https://api.myshoptet.com/api/stocks/#{warehouse_id}/movements", api_params)
  end

  def product_categories api_params = {}
    enumerize('https://api.myshoptet.com/api/categories', api_params)
  end

  def products_changes api_params = {}
    enumerize('https://api.myshoptet.com/api/products/changes', api_params)
  end

  def price_lists api_params = {}
    enumerize('https://api.myshoptet.com/api/pricelists', api_params)
  end

  def prices price_list_id, api_params = {}
    enumerize("https://api.myshoptet.com/api/pricelists/#{price_list_id}", api_params, 'pricelist')
  end

  def orders api_params = {}
    enumerize('https://api.myshoptet.com/api/orders', api_params)
  end

  def orders_changes from:
    api_params = { from: from.iso8601 }
    enumerize('https://api.myshoptet.com/api/orders/changes', api_params)
  end

  def order code, api_params = {}
    result = request("https://api.myshoptet.com/api/orders/#{code}", api_params)
    result.dig('data', 'order')
  end

  def product guid, api_params = {}
    result = request("https://api.myshoptet.com/api/products/#{guid}", api_params)
    result['data']
  end

  def product_by_code code, api_params = {}
    result = request("https://api.myshoptet.com/api/products/code/#{code}", api_params)
    result['data']
  end

  def new_api_token
    headers = { 'Authorization' => "Bearer #{@oauth_token}" }

    result = Shoptet::Request.get(URI(@oauth_url), headers)
    handle_errors(result)

    result.fetch('access_token')
  end

  def request url, api_params = {}, retry_on_token_error = true
    url = URI(url)
    url.query = URI.encode_www_form(api_params) if api_params.any?

    headers = { 'Shoptet-Access-Token' => @api_token,
                'Content-Type' => 'application/vnd.shoptet.v1.0' }

    result = Shoptet::Request.get(url, headers)
    token_errors = handle_errors(result)

    if token_errors.any?
      if retry_on_token_error
        @on_token_error.call(self)
        request(url, api_params, false)
      else
        raise Error.new(result)
      end
    else
      result
    end
  end

  def suspended?
    false if shop_info
  rescue Shoptet::AddonSuspended
    true
  end

  private

  def enumerize base_url, filters = {}, data_key = nil
    ApiEnumerator.new(base_url, filters, data_key, self)
  end

  def handle_errors result
    error = result['error']
    errors = result['errors'] || []
    token_errors, non_token_errors = errors.partition do |err|
      code = err['errorCode']
      message = err['message']

      code == EXPIRED_TOKEN_CODE ||
        code == INVALID_TOKEN_CODE && (message.include?('Invalid access token') || message.include?('Missing access token'))
    end

    if error || non_token_errors.any?
      if error == 'addon_suspended' || errors.any? { |e| e["errorCode"] == INVALID_TOKEN_CODE && e['message'] == ADDON_NOT_INSTALLED }
        raise AddonSuspended
      elsif (error == 'addon_not_installed')
        raise AddonNotInstalled
      elsif errors.any? { |err| err["errorCode"] == 'invalid-token-no-rights' }
        raise InvalidTokenNoRights
      elsif errors.any? { |err| err["errorCode"] == 'stock-not-found' }
        raise StockNotFound
      elsif errors.any? { |err| err["errorCode"] == 'page-not-found' && err['message'].include?('max page is') }
        raise MaxPageReached
      else
        raise Error.new result
      end
    end

    token_errors
  end
end
