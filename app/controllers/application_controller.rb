class ApplicationController < ActionController::Base
  include Devise::Controllers::Helpers
  devise_group :user, contains: [:user]

  private

  def current_user_is_allowed_to_log_in?
    return true if Rails.env.development? && current_user.uid == DEVELOPMENT_USER_CONFIG[:uid]
    return true if ALLOWED_USER_IDS.include?(current_user.uid)
    return true if (ALLOWED_USER_AFFILS & current_user.affils).present?

    false
  end

    def add_cors_header!
      headers['Access-Control-Allow-Origin'] = '*'
    end
end
