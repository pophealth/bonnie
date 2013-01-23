Bonnie::Application.routes.draw do

  resources :measures do
    member do
      get :export
      get :import_resource
      post :publish
      get :show_nqf
      get :debug_rationale
      match :upsert_criteria
      get :debug  # measure debug page
      match 'test(/:measure_patients)' => 'Measures#test', :as => :test
      get :test   # select patients form
      get 'debug/:record_id' => 'Measures#debug', :as => :debug_measure   # FIXME: too nested - cdillon
      post :test  # handle select patients form
      post :generate_patients
      get :download_patients
      post :delete_population
      post :add_population
      post :update_population
      post :update_population_criteria
      post :name_precondition
      post :save_data_criteria
      get :patient_builder
      get 'patient_builder/:patient_id' => 'Measures#patient_builder', :as => 'edit_patient'
      post :make_patient
      post :delete_patient
      get :generate_matrix
    end
    collection do
      get :published
      get :export_all
      get :debug_libraries
      get :generate_matrix
      get :matrix
      get :matrix_data
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

  resources :value_sets

 end
