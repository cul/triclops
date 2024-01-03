class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers
  devise_group :user, contains: [:user]
  before_filter before_filter :authenticate_user!, if: :devise_controller?

  private

    def add_cors_header!
      headers['Access-Control-Allow-Origin'] = '*'
    end
end
