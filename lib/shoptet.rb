require_relative 'shoptet/request'

class Shoptet
  class Error < StandardError
    #TODO: check that this works
    attr_reader :additional_data

    def initialize message, additional_data = {}
      super(message)
      @additional_data = additional_data
    end
  end
  class AddonSuspended < StandardError; end
  class AddonNotInstalled < StandardError; end

  DEFAULT_ON_TOKEN_ERROR = -> (api) do
    api.api_token = api.new_api_token
  end

  def self.version
    '0.0.3'
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

  attr_accessor :api_token

  def initialize(oauth_url, oauth_token, api_token = nil, on_token_error = nil)
    @oauth_url = oauth_url
    @oauth_token = oauth_token
    @api_token = api_token
    @on_token_error = on_token_error || DEFAULT_ON_TOKEN_ERROR
  end

  def shop_info api_params = {}
    request 'https://api.myshoptet.com/api/eshop'
  end

  def warehouses api_params = {}
    enumerize 'https://api.myshoptet.com/api/stocks', api_params
  end

  def products api_params = {}
    enumerize "https://api.myshoptet.com/api/products", api_params
  end

  def supplies warehouse_id, api_params = {}
    uri = "https://api.myshoptet.com/api/stocks/#{warehouse_id}/supplies"
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
    result.dig('data', 'order').merge(detail_url: uri)
  end

  def product guid, api_params = {}
    uri = "https://api.myshoptet.com/api/products/#{guid}"
    result = request assemble_uri(uri, api_params)
    result.dig('data')
  end

  def new_api_token
    headers = { 'Authorization' => "Bearer #{@oauth_token}" }

    result = Shoptet::Request.get @oauth_url, headers
    handle_errors result, @oauth_url, headers

    result.fetch 'access_token'
  end

  private

  def assemble_uri base, params = {}
    u = URI(base)
    u.query = URI.encode_www_form(params) if params.any?

    u.to_s
  end

  def enumerize base_uri, filters = {}, data_key = nil
    data_key ||= URI(base_uri).path.split('/').last
    uri = assemble_uri base_uri, filters
    size_proc = -> () { request(uri)['data']['paginator']['totalCount'] }

    Enumerator.new(size_proc) do |y|
      first_page = request uri
      total_pages = first_page.dig('data', 'paginator', 'pageCount') || 0
      other_pages = 2..total_pages

      first_page.dig('data', data_key).each { y.yield _1.merge(page_url: uri) }

      other_pages.each do |page|
        uri = assemble_uri base_uri, filters.merge(page: page)
        result = request uri
        result.dig('data', data_key).each { y.yield _1.merge(page_url: uri) }
      end
    end
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

  def handle_errors result, uri, headers
    error = result['error']
    errors = result['errors'] || []
    token_errors, non_token_errors = errors.partition { |err| ['invalid-token', 'expired-token'].include? err['errorCode'] }

    if error || non_token_errors.any?
      if error == 'addon_suspended'
        raise AddonSuspended
      elsif error == 'addon_not_installed'
        raise AddonNotInstalled
      else
        additional_data = {
          uri: uri,
          headers: scrub_sensitive_headers(headers)
        }

        raise Error.new result, additional_data
      end
    end

    token_errors
  end

  def scrub_sensitive_headers headers
    scrubbed = {}

    to_scrub = ['Shoptet-Access-Token', 'Authorization']
    to_scrub.each do |header|
      if headers[header]
        scrubbed[header] = "#{headers[header][0..20]}..."
      end
    end

    headers.merge scrubbed
  end
end
