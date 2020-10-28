module Shoptet
  module Shop
    def with_bg_jobs_api_token
      @bg_jobs_token = bg_jobs_api_access_token

      result = catch :invalid_api_token do
        yield @bg_jobs_token
      end

      if result == 'invalid_token' || result == 'expired_token'
        with_lock do
          reload

          if bg_jobs_api_access_token != @bg_jobs_token
            @new_token = bg_jobs_api_access_token
          else
            @new_token = generate_new_token
            update(bg_jobs_api_access_token: @new_token)
          end
        end

        yield @new_token
      end
    end
  end
end
