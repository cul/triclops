Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'application#home'

  namespace :api do
    namespace :v1 do
      resources :resources
    end
  end

  namespace :iiif do
    scope ':version', version: /2/, defaults: { version: 2 } do
      get '/:identifier/:region/:size/:rotation/:quality', to: 'images#raster', as: 'raster'
      get '/:identifier/info.json', to: 'images#info', as: 'info'
      get '/test_viewer', to: redirect('/iiif/2/test_viewer/sample'), as: 'test_viewer_default'
      get '/test_viewer/:identifier', to: 'images#test_viewer', as: 'test_viewer'
    end
  end
end
