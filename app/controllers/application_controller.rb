class ApplicationController < ActionController::Base
  def home
    render plain: "Triclops\nVersion #{VERSION}"
  end

  private

    def add_cors_header!
      headers['Access-Control-Allow-Origin'] = '*'
    end
end
