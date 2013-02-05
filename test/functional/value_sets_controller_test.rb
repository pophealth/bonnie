require 'test_helper'

class ValueSetsControllerTest < ActionController::TestCase
  include Devise::TestHelpers
  
  # setup do
  #   dump_database
  #   @vs = FactoryGirl.build(:value_set)
  #   @user = FactoryGirl.create(:user)
  #   sign_in @user
  # end
  
  # test "index" do
  #   get :index

  #   assert_response :success
  #   assert_template :index
  #   refute_nil assigns(:value_sets)
  # end
  
  # test "new value set" do
  #   get :new
    
  #   assert_response :success
  #   refute_nil assigns(:value_set)
  # end
  # # 
  # # test "destroy value set" do
  # #   assert @vs.save
  # #   delete :destroy, id: @vs.id
  # #   assert assigns(:value_set).destroyed?
  # #   assert_response 302
  # #   assert_redirected_to value_sets_path
  # # end
  # # 
  # test "should create a valid value set" do
  #   post :create, format:'json', data: @vs.attributes
  #   assert_response 200
    
  #   json_response = JSON.parse @response.body
  #   assert json_response["message"] == "success"

  #   assert flash[:error].nil?
  #   assert assigns(:value_set).class == HealthDataStandards::SVS::ValueSet
  #   assert assigns(:value_set).valid?
  # end
  
  # test "should update a value set" do
  #   assert @vs.save
  #   @vs2 = FactoryGirl.build(:value_set)
    
  #   put :update, format:'json', id: @vs._id, category: @vs2.category
  #   @vs.reload
  #   assert_equal @vs2.category, @vs.category
  # end

  # # test "show" do
  # #   assert @vs.save
  # #   
  # #   get :show, id: @vs.id
  # #   
  # #   assert_response :success
  # #   assert_template :show
  # # end
end
