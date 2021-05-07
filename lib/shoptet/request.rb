require 'net/http'
require 'oj'

class Shoptet
  class Request
    def self.get url, headers
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.open_timeout = 60
      http.read_timeout = 60
      http.write_timeout = 60
      http.ssl_timeout = 60

      request = Net::HTTP::Get.new(url)
      headers.each do |key, value|
        request[key] = value
      end

      response = http.request(request)
      parsed_body = Oj.load(response.body, mode: :compat)

      unless parsed_body
        message = "Status code: #{response.code}, url: #{url}"
        fail Shoptet::EmptyResponse.new(message)
      end

      parsed_body
    rescue Net::OpenTimeout => e
      raise(e.class, "#{e.message} - on url #{url}")
    end

    def self.post url, body
      request = Net::HTTP::Post.new(url)
      request.set_form_data(body)

      response = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        http.request(request)
      end

      Oj.load(response.body, mode: :compat)
    end
  end
end
