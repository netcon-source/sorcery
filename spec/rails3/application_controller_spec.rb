require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ApplicationController do
  before(:all) do
    ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate/core")
  end
  
  after(:all) do
    ActiveRecord::Migrator.rollback("#{Rails.root}/db/migrate/core")
  end
  
  # ----------------- PLUGIN LOADED -----------------------
  describe ApplicationController, "when app has plugin loaded" do
    it "should respond to the plugin activation class method" do
      ActionController::Base.should respond_to(:activate_sorcery!)
      ApplicationController.should respond_to(:activate_sorcery!)
    end
    
    it "plugin activation should yield config to block" do
      ApplicationController.activate_sorcery! do |config|
        config.should == ::Sorcery::Controller::Config 
      end
    end
    
    it "config.should respond to 'submodules='" do
      ApplicationController.activate_sorcery! do |config|
        config.should respond_to(:submodules=)
      end
    end
  end
 
  # ----------------- PLUGIN CONFIGURATION -----------------------
  describe ApplicationController, "plugin configuration" do
    before(:all) do
      plugin_model_configure
    end
    
    after(:each) do
      Sorcery::Controller::Config.reset!
      plugin_model_configure
    end
  
    it "submodule configuration should effect model" do
      ApplicationController.activate_sorcery! do |config|
        config.submodules = [:test_submodule] 
      end
      User.class_eval do
        activate_sorcery!
      end
      User.new.should respond_to(:my_instance_method)
    end
    
    it "should enable configuration option 'user_class'" do
      plugin_set_controller_config_property(:user_class, TestUser)
      Sorcery::Controller::Config.user_class.should equal(TestUser)
    end
    
    it "should enable configuration option 'session_attribute_name'" do
      plugin_set_controller_config_property(:session_attribute_name, :my_session)
      Sorcery::Controller::Config.session_attribute_name.should equal(:my_session)
    end
    
    it "should enable configuration option 'cookies_attribute_name'" do
      plugin_set_controller_config_property(:cookies_attribute_name, :my_cookies)
      Sorcery::Controller::Config.cookies_attribute_name.should equal(:my_cookies)
    end
    
    it "should enable configuration option 'not_logged_in_action'" do
      plugin_set_controller_config_property(:not_logged_in_action, :my_action)
      Sorcery::Controller::Config.not_logged_in_action.should equal(:my_action)
    end
    
  end

  # ----------------- PLUGIN ACTIVATED -----------------------
  describe ApplicationController, "when activated with sorcery" do
    before(:all) do
      create_new_user
    end
  
    it "should respond to the instance method login" do
      should respond_to(:login)
    end
  
    it "should respond to the instance method logout" do
      should respond_to(:logout)
    end
  
    it "should respond to the instance method logged_in?" do
      should respond_to(:logged_in?)
    end
    
    it "should respond to the instance method logged_in_user" do
      should respond_to(:logged_in_user)
    end
  
    it "login(user) should return the user when success and set the session with user.id" do
      get :test_login, :user => {:username => 'gizmo', :password => 'secret'}
      assigns[:user].should == @user
      session[:user_id].should == @user.id
    end
  
    it "login(user) should return nil and not set the session when failure" do
      get :test_login, :user => {:username => 'gizmo', :password => 'opensesame!'}
      assigns[:user].should be_nil
      session[:user_id].should be_nil
    end
  
    it "logout should clear the session" do
      cookies[:remember_me_token] = nil
      session[:user_id] = @user.id
      get :test_logout
      session[:user_id].should be_nil
    end
  
    it "logged_in? should return true if logged in" do
      session[:user_id] = @user.id
      subject.logged_in?.should be_true
    end
  
    it "logged_in? should return false if not logged in" do
      session[:user_id] = nil
      subject.logged_in?.should be_false
    end
    
    it "logged_in_user should return the user instance if logged in" do
      create_new_user
      session[:user_id] = @user.id
      subject.logged_in_user.should == @user
    end
    
    it "logged_in_user should return false if not logged in" do
      session[:user_id] = nil
      subject.logged_in_user.should == false
    end
    
    it "should respond to 'authenticate'" do
      should respond_to(:authenticate)
    end
    
    it "should call the configured 'not_logged_in_action' when authenticate before_filter fails" do
      session[:user_id] = nil
      plugin_set_controller_config_property(:not_logged_in_action, :test_not_logged_in_action)
      get :test_logout
      response.body.should == "test_not_logged_in_action"
    end
  end
  
  # ----------------- REMEMBER ME -----------------------
  describe ApplicationController, "with remember me features" do
    before(:all) do
      ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate/remember_me")
      plugin_controller_configure([:remember_me])
      plugin_model_configure([:remember_me])
      create_new_user
    end
    
    after(:all) do
      ActiveRecord::Migrator.rollback("#{Rails.root}/db/migrate/remember_me")
    end
    
    it "should set cookie on remember_me!" do
      post :test_login_with_remember, :user => {:username => 'gizmo', :password => 'secret'}
      cookies["remember_me_token"].should == assigns[:logged_in_user].remember_me_token
    end
    
    it "should clear cookie on forget_me!" do
      cookies["remember_me_token"] == 'asd54234dsfsd43534'
      get :test_logout
      cookies["remember_me_token"].should == nil
    end
  end
end