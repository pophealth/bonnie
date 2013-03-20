Bonnie::Application.routes.draw do

  resources :matrix do
    collection do
      get :generate_matrix
      get :matrix_data
    end
  end

  resources :debug do
    member do 
      post :show 
      get :inspect
      get :rationale
    end
    collection do
      get :libraries
    end
  end

  resources :patients do
    member do 
      post :save  
    end
    collection do
      get :download
    end
  end

  resources :measure_builder do
    member do
      match :upsert_criteria
      post :update_population_criteria
      post :save_data_criteria
      post :name_precondition
    end
  end


  resources :measures do
    member do
      post :publish
      get :show_nqf
      post :delete_population
      post :add_population
      post :update_population
      post :update_population_criteria
      post :name_precondition
      post :save_data_criteria
    end
    collection do
      get :published
      get :export
      post :load_measures
      post :download_measures
      get :poll_load_job_status
    end
  end

  get 'measures/:id/population_criteria/definition' => 'measures#population_criteria_definition', :as => :population_criteria_definition
  get 'measures/:id/:population' => 'measures#show', :constraints => {:population => /\d+/}
  get 'measures/:id/definition' => 'measures#definition'
  get 'measures/:id/:population/definition' => 'measures#definition'

  devise_for :users, :controllers => {:registrations => "registrations"}

  root :to => 'measures#index'

  #resources :value_sets

 end
