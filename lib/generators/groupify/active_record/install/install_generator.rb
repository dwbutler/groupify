module Groupify
  module ActiveRecord
    class InstallGenerator < Rails::Generators::Base
      def invoke_generators
        %w{ model migration initializer }.each do |name|
          generate "groupify:active_record:#{name}"
        end
      end
    end
  end
end

