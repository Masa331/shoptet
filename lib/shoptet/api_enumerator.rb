class Shoptet
  class ApiEnumerator < SimpleDelegator
    def initialize base_url, filters, data_key, api
      @base_url = base_url
      @filters = filters
      @data_key = data_key || URI(base_url).path.split('/').last
      @api = api

      @enum = Enumerator.new do |y|
        first_page.dig('data', @data_key).each { y.yield _1 }

        if total_pages > 1
          other_pages = 2..(total_pages - 1)
          other_pages.each do |page|
            result = @api.request(base_url, filters.merge(page: page))
            result.dig('data', @data_key).each { y.yield _1 }
          end

          last_page.dig('data', @data_key).each { y.yield _1 }
        end
      end

      super @enum
    end

    def first_page
      @first_page ||= @api.request(@base_url, @filters)
    end

    def last_page
      return first_page if total_pages < 2

      @last_page ||= @api.request(@base_url, @filters.merge(page: total_pages))
    end

    def total_pages
      first_page.dig('data', 'paginator', 'pageCount') || 0
    end

    def size
      first_page.dig('data', 'paginator', 'totalCount')
    end
  end
end
