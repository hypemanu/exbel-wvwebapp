Rails.application.routes.draw do
  devise_for :users
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :readings, only: [:index, :create, :new, :destroy]
  get 'welcome' => "home#welcome"
  
  root 'readings#index'
end
