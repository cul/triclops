# frozen_string_literal: true

require 'resque/server'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'pages#home'
  get 'admin/resources', to: 'pages#home'

  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  devise_scope :user do
    if Rails.env.development?
      get '/users/development/sign_in_developer', to: 'users/development#sign_in_developer'
      get '/users/development/output_current_user', to: 'users/development#output_current_user'
    end
  end

  resque_web_constraint = lambda do |request|
    current_user = request.env['warden'].user
    current_user.present?
  end

  constraints resque_web_constraint do
    mount Resque::Server.new, at: '/resque'
  end

  namespace :api do
    namespace :v1, defaults: { format: :json } do
      resources :resources, only: [:show, :destroy, :index]
      # Rather than using the built-in "update" controller action naming convention, we'll point
      # put/patch to a "create_or_replace" controller action to clarify what these routes do.
      [:put, :patch].each do |method|
        send(method, 'resources/:id' => 'resources#create_or_replace', as: nil)
      end
    end
  end

  namespace :iiif do
    scope ':version', version: /2/, defaults: { version: 2 } do
      get '/test_viewer', to: redirect('/iiif/2/test_viewer/sample'), as: 'test_viewer_default'
      get '/test_viewer/:identifier', to: 'images#test_viewer', as: 'test_viewer'
      get '/:identifier/:region/:size/:rotation/:quality', to: 'images#raster', as: 'raster'
      get '/:identifier/info.json', to: 'images#info', as: 'info'
    end
  end
end
