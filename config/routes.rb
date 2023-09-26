Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'pages#home'

  namespace :api do
    namespace :v1 do
      resources :resources, only: [:show, :destroy]
      # Rather than using the built-in "update" controller action naming convention, we'll point
      # put/patch to a "create_or_update" controller action to clarify what these routes do.
      [:put, :patch].each do |method|
        send(method, 'resources/:id' => 'resources#create_or_update', as: nil)
      end
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
