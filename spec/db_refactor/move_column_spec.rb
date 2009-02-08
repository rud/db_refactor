require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

require 'db_refactor/move_column'

describe DbRefactor::MoveColumn do
  load_rails_environment

  class Invocator < ActiveRecord::Migration
    include DbRefactor::MoveColumn # notice this ends up on ActiveRecord::Migration, see init.rb

    def self.up
      move_column 'favorite_color', :fancy_users, :target_profiles
    end

    def self.down
      move_column 'favorite_color', :target_profiles, :fancy_users
    end
  end

  describe "include hook" do
    it "should respond to method from MoveColumn" do
      Invocator.new.should respond_to(:move_column)
    end
  end

  describe "integration test with database" do
    class FancyUser < ActiveRecord::Base
      has_one :target_profile
    end
    class TargetProfile < ActiveRecord::Base
      belongs_to :fancy_user
    end

    before :each do
      setup_rails_database
      FancyUser.reset_column_information
      TargetProfile.reset_column_information
    end

    after :each do
      drop_rails_database
    end

    describe "initial condition" do
      it "should have a fancy_users table" do
        user = FancyUser.create(:name => 'the first')
        user.target_profile.should be_blank
      end

      it "should have sane target_profiles table" do
        user = FancyUser.create(:name => 'him')
        profile = TargetProfile.create(:name => 'the first', :fancy_user => user)
        profile.fancy_user.should == user
      end
    end

    describe ".move_column()" do
      before :each do
        @user = FancyUser.create(:name => 'Peter Griffin', :favorite_color => 'blue')
        @user.create_target_profile(:name => 'some profile setting')
      end

      def do_invoke
        Invocator.up
      end

      it "should have favorite_color on user" do
        @user.should respond_to(:favorite_color)
      end

      it "should not have favorite_color on profile" do
        @user.target_profile.should_not respond_to(:favorite_color)
      end

      it "should automatically reload columns for user" do
        FancyUser.expects(:reset_column_information)
        do_invoke
      end

      it "should automatically reload columns for target" do
        TargetProfile.expects(:reset_column_information)
        do_invoke
      end

      it "should move column to target" do
        do_invoke
        @user.target_profile.should respond_to(:favorite_color)
      end

      describe 'the new column in the target table' do
        it 'should have the same attributes as the column in the from table' do
          from_column_attributes = FancyUser.new.column_for_attribute('favorite_number')
          Invocator.move_column 'favorite_number', :fancy_users, :target_profiles
          TargetProfile.new.column_for_attribute('favorite_number').to_yaml.should == from_column_attributes.to_yaml
        end
      end

      it "should no longer be on user when creating new" do
        do_invoke
        FancyUser.new.should_not respond_to(:favorite_color)
      end

      it "should not fix existing instances" do
        do_invoke
        @user.should respond_to(:favorite_color) #notice: @user.favorite_color still exist
        @user.favorite_color.should == 'blue'
      end

      it "should retain the value" do
        do_invoke
        reloaded_user = FancyUser.find(@user)
        reloaded_user.target_profile.favorite_color.should == 'blue'
      end

      it "should create the referenced object if it is missing" do
        no_profile = FancyUser.create(:name => 'No profile here', :favorite_color => 'red')
        do_invoke
        no_profile.target_profile.favorite_color.should == 'red'
      end

      describe "paginated find" do
        before :each do
          FancyUser.delete_all; TargetProfile.delete_all
          1.upto(60) do |i|
            FancyUser.create(:name => "fancy #{i}", :favorite_color => "super intelligent shade of blue ##{i + 42}")
          end
        end

        it "should page through all source-objects 50 at a time" do
          FancyUser.expects(:all).returns([])
          FancyUser.expects(:all).with(has_entry(:limit => 50)).times(2).returns([FancyUser.create]).times(2)
          do_invoke
        end

        it "should order by id" do
          FancyUser.expects(:all).returns([])
          FancyUser.expects(:all).with(has_entry(:order => 'id')).times(2).returns([FancyUser.create]).times(2)
          do_invoke
        end

        it "should create a profile for each" do
          do_invoke
          TargetProfile.count.should == 60
        end
      end
    end
  end
end
