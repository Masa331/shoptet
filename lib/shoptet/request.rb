require 'net/http'
require 'json'

class Shoptet
  class Request
    def self.get url, headers
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = 30
      http.read_timeout = 30
      http.write_timeout = 30
      http.ssl_timeout = 30

      request = Net::HTTP::Get.new(url)
      headers.each do |key, value|
        request[key] = value
      end

      response = handle_net_timeouts { http.request(request) }
      parsed_body = JSON.parse(response.body)

      unless parsed_body
        message = "Status code: #{response.code}, url: #{url}"
        fail Shoptet::EmptyResponse.new(message)
      end

      parsed_body
    end

    def self.post url, body
      request = Net::HTTP::Post.new(url)
      request.set_form_data(body)

      response = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        handle_net_timeouts { http.request(request) }
      end

      JSON.parse(response.body)
    end

    private

    def self.handle_net_timeouts
      begin
        yield
      rescue Net::OpenTimeout
        yield
      end
    end
  end
end
