module Core
  module FlatMap
    module Mapper::ModelMethods
      extend ActiveSupport::Concern

      included do
        define_callbacks :save
      end

      module ClassMethods
        def build(*traits)
          new(target_class.new, *traits)
        end

        def find(id, *traits)
          new(target_class.find(id), *traits)
        end

        def target_class
          target_class_name.constantize
        end

        def target_class_name=(class_name)
          @target_class_name = class_name
        end

        def target_class_name
          @target_class_name ||= self.name[/^(\w+)Mapper.*$/, 1]
        end
      end

      def model_name
        'mapper'
      end

      def to_key
        target.to_key
      end

      def apply(params)
        write(params)
        !!(save if valid?)
      end

      def write(params)
        params.each do |name, value|
          self.send("#{name}=", value)
        end
      end

      def save
        ActiveRecord::Base.transaction do
          run_callbacks :save do
            res = target.respond_to?(:save) ? target.save : true
            mountings.each do |mapper|
              break unless res
              res = mapper.save
            end
            res
          end
        end
      end

      def valid?
        res = super
        mounted_res = all_mountings.map(&:valid?).all?
        consolidate_errors!
        res && mounted_res
      end

      def consolidate_errors!
        mountings.map(&:errors).each do |errs|
          errors.messages.merge!(errs.to_hash){ |k, old, new| old.concat(new) }
        end
      end
      private :consolidate_errors!
    end
  end
end
