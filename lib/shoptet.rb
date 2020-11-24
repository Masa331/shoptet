require 'delegate'
require_relative 'shoptet/request'

class Shoptet
  include Shoptet::UrlHelpers

  class Error < StandardError; end
  class AddonSuspended < StandardError; end
  class AddonNotInstalled < StandardError; end
  class InvalidTokenNoRights < StandardError; end
  class EmptyRequestResponse < StandardError; end
  class MaxPageReached < StandardError; end

  EXPIRED_TOKEN_CODE = 'expired-token'
  INVALID_TOKEN_CODE = 'invalid-token'
  ADDON_NOT_INSTALLED = 'Addon installation is not approved.'

  DEFAULT_ON_TOKEN_ERROR = -> (api) do
    api.api_token = api.new_api_token
  end

  class ApiEnumerator < SimpleDelegator
    def initialize base_url, filters, data_key, api
      @base_url = base_url
      @filters = filters
      @data_key = data_key ||  URI(base_url).path.split('/').last
      @api = api

      @enum = Enumerator.new do |y|
        first_page.dig('data', @data_key).each { y.yield _1 }

        if total_pages > 1
          other_pages = 2..(total_pages - 1)
          other_pages.each do |page|
            uri = @api.assemble_uri base_url, filters.merge(page: page)
            result = @api.request uri
            result.dig('data', @data_key).each { y.yield _1 }
          end

          last_page.dig('data', @data_key).each { y.yield _1 }
        end
      end

      super @enum
    end

    def first_page
      @first_page ||=
        begin
          uri = @api.assemble_uri @base_url, @filters
          @api.request uri
        end
    end

    def total_pages
      first_page.dig('data', 'paginator', 'pageCount') || 0
    end

    def last_page
      return first_page if total_pages < 2

      @last_page ||=
        begin
          uri = @api.assemble_uri @base_url, @filters.merge(page: total_pages)
          @api.request uri
        end
    end

    def size
      first_page['data']['paginator']['totalCount']
    end
  end

  def self.version
    '0.0.14'
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

    Shoptet::Request.post url, data
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

    Shoptet::Request.post url, data
  end

  def self.basic_eshop url, access_token
    Shoptet::Request.get url, { 'Authorization' => "Bearer #{access_token}" }
  end

  attr_accessor :api_token

  def initialize oauth_url:, oauth_token:, shop_url:, client_id:, api_token: nil, on_token_error: nil
    @oauth_url = oauth_url
    @oauth_token = oauth_token
    @shop_url = shop_url
    @client_id = client_id
    @api_token = api_token
    @on_token_error = on_token_error || DEFAULT_ON_TOKEN_ERROR
  end

  def endpoints api_params = {}
    enumerize 'https://api.myshoptet.com/api/system/endpoints', api_params
  end

  def endpoint_approved? endpoint
    @approved_endpoints ||= endpoints

    @approved_endpoints.any? { _1['endpoint'] == endpoint }
  end

  def authorize_url redirect_url, state
    query = {
      client_id: @client_id,
      state: state,
      scope: 'basic_eshop',
      response_type: 'code',
      redirect_uri: redirect_url
    }.to_query

    URI("#{@shop_url}action/OAuthServer/authorize?#{query}").to_s
  end

  def shop_info api_params = {}
    url = assemble_uri 'https://api.myshoptet.com/api/eshop', api_params
    result = request url
    result['data']
  end

  def design_info api_params = {}
    url = assemble_uri 'https://api.myshoptet.com/api/eshop/design', api_params
    result = request url

    result['data']
  end

  def stocks api_params = {}
    enumerize 'https://api.myshoptet.com/api/stocks', api_params
  end

  def products api_params = {}
    enumerize "https://api.myshoptet.com/api/products", api_params
  end

  def supplies warehouse_id, api_params = {}
    uri = "https://api.myshoptet.com/api/stocks/#{warehouse_id}/supplies"
    enumerize uri, api_params
  end

  def stocks_movements warehouse_id, api_params = {}
    uri = "https://api.myshoptet.com/api/stocks/#{warehouse_id}/movements"
    enumerize uri, api_params
  end

  def product_categories api_params = {}
    enumerize 'https://api.myshoptet.com/api/categories', api_params
  end

  def products_changes api_params = {}
    uri = 'https://api.myshoptet.com/api/products/changes'
    enumerize uri, api_params
  end

  def price_lists api_params = {}
    enumerize 'https://api.myshoptet.com/api/pricelists', api_params
  end

  def prices price_list_id, api_params = {}
    uri = "https://api.myshoptet.com/api/pricelists/#{price_list_id}"
    enumerize uri, api_params, 'pricelist'
  end

  def orders api_params = {}
    enumerize 'https://api.myshoptet.com/api/orders', api_params
  end

  def orders_changes api_params = {}
    uri = 'https://api.myshoptet.com/api/orders/changes'
    enumerize uri, api_params
  end

  def order code, api_params = {}
    uri = "https://api.myshoptet.com/api/orders/#{code}"
    result = request assemble_uri(uri, api_params)
    result.dig 'data', 'order'
  end

  def product guid, api_params = {}
    uri = "https://api.myshoptet.com/api/products/#{guid}"
    result = request assemble_uri(uri, api_params)
    result['data']
  end

  def new_api_token
    headers = { 'Authorization' => "Bearer #{@oauth_token}" }

    result = Shoptet::Request.get @oauth_url, headers
    handle_errors result, @oauth_url, headers

    result.fetch 'access_token'
  end

  def request uri, retry_on_token_error = true
    headers = { 'Shoptet-Access-Token' => @api_token,
                'Content-Type' => 'application/vnd.shoptet.v1.0' }

    result = Shoptet::Request.get uri, headers
    token_errors = handle_errors result, uri, headers

    if token_errors.any?
      if retry_on_token_error
        @on_token_error.call self
        request uri, false
      else
        raise Error.new result
      end
    else
      result
    end
  end

  def suspended?
    data = shop_info

    false if data
  rescue Shoptet::AddonSuspended
    true
  end

  private

  def enumerize base_url, filters = {}, data_key = nil
    ApiEnumerator.new base_url, filters, data_key, self
  end

  def handle_errors result, uri, headers
    error = result['error']
    errors = result['errors'] || []
    token_errors, non_token_errors = errors.partition do |err|
      code = err['errorCode']
      message = err['message']

      code == EXPIRED_TOKEN_CODE ||
        code == INVALID_TOKEN_CODE && message == "Invalid access token."
    end

    if error || non_token_errors.any?
      if error == 'addon_suspended' || errors.any? { |e| e["errorCode"] == INVALID_TOKEN_CODE && e['message'] == ADDON_NOT_INSTALLED }
        raise AddonSuspended
      elsif (error == 'addon_not_installed')
        raise AddonNotInstalled
      elsif errors.any? { |err| err["errorCode"] == 'invalid-token-no-rights' }
        raise InvalidTokenNoRights
      elsif errors.any? { |err| err["errorCode"] == 'page-not-found' && err['message'].include?('max page is') }
        raise MaxPageReached
      else
        raise Error.new result
      end
    end

    token_errors
  end
end
