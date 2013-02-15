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
        extract_multiparams!(params)

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

      def extract_multiparams!(params)
        all_mappings.select(&:multiparam?).each do |mapping|
          param_keys = params.keys.
            select{ |k| k.to_s =~ /#{mapping.name}\(\d+[isf]\)/ }.
            sort_by{ |k| k.to_s[/\((\d+)\w*\)/, 1].to_i }

          next if param_keys.empty?

          args = param_keys.inject([]) do |values, key|
            value = params.delete key
            type  = key[/\(\d+(\w*)\)/, 1]
            value = value.send("to_#{type}") unless type.blank?

            values.push value
            values
          end

          params[mapping.name] = mapping.multiparam.new(*args) rescue nil
        end
      end
    end
  end
end
