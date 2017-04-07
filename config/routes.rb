Rails.application.routes.draw do
  devise_for :users

  authenticated :user do
    root 'readings#index', as: :authenticated_root
  end
  
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :readings, only: [:index, :create, :new, :destroy]

  get 'welcome' => "home#welcome"
  
  root 'home#welcome'
end
