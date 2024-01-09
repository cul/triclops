class Users::SessionsController < Devise::SessionsController
  def new_session_path(_scope)
    new_user_session_path # this accomodates Users namespace of the controller
  end

  def omniauth_provider_key
    # there is support for :wind, :cas, and :saml in Cul::Omniauth
  end

  # (Without this, visit /users/auth/saml explicitly)
  # GET /resource/sign_in
  def new
    redirect_to user_saml_omniauth_authorize_path
  end

  # Log in with a development account instead of the default CAS login.
  # Used only in the development environment, as a convenience.
  def developer_new
    puts 'in development'
    return unless Rails.env.development?

    unless user_signed_in?
      dev_user = User.find_by(
        uid: DEVELOPMENT_USER_CONFIG[:uid]
      ) || User.create!(DEVELOPMENT_USER_CONFIG)

      sign_in(dev_user, scope: :user)
    end
    puts 'signed in developer'
    redirect_to root_path
  end
end
