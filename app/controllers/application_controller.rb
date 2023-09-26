class ApplicationController < ActionController::Base
  private

    def add_cors_header!
      headers['Access-Control-Allow-Origin'] = '*'
    end
end
