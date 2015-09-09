module Groupify
  module Mongoid
    class InstallGenerator < Rails::Generators::Base
      def invoke_generators
        %w{ initializer model }.each do |name|
          generate "groupify:mongoid:#{name}"
        end
      end
    end
  end
end

