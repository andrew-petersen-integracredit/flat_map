module Core
  module FlatMap
    class FormFlow
      class StepSetup < Struct.new(:options, :setup)
        delegate :call, :[], :to => :setup

        def have_setup?
          setup.present?
        end

        def traits
          options[:traits]
        end
      end

      attr_reader :controller, :step, :mapper

      delegate :params, :to => :controller

      def self.mount(mapper_name)
        @mapper_name = mapper_name
        define_method(mapper_name){ mapper.target }
      end

      def self.step(options, &block)
        steps.push StepSetup.new(options, block)
      end

      def self.initially(&block)
        return @initial_setup unless block_given?
        @initial_setup = block
      end

      # def self.finally(&block)
      #   return @final_setup unless block_given?
      #   @final_setup = block
      # end

      def self.steps
        @steps ||= []
      end

      def self.mapper_class
        "#{@mapper_name.to_s.camelize}Mapper".constantize
      end

      def self.mapper_params_key
        "#{@mapper_name}_mapper"
      end

      def self.mapper_session_key
        :"#{@mapper_name}_id"
      end

      def initialize(controller)
        @controller = controller
        @step = params[:step].try(:to_i) || 1
        controller.instance_variable_set(:@flow, self)
        initial_setup
        controller_data_prepare
      end

      def initial_setup
        return unless step == 1
        setup = self.class.initially
        setup[controller, self] if setup.present?
      end

      def final_setup
        #setup = self.class.finally
        setup = self.class.steps.last
        setup[controller, self] if setup.present?
      end

      def mapper
        @mapper ||= fetch_mapper
      end

      def process
        if mapper.apply(params[self.class.mapper_params_key])
          increment_step!
          if finished?
            final_setup
          else
            post_step_setup
            controller_data_prepare
            @mapper = nil
          end
        end
      end

      def fetch_mapper
        setup = self.class.steps[step-1]
        return self.class.mapper_class.build(*setup.traits) if step == 1
        #return self.class.mapper_class.build(*setup.traits) if controller.session[self.class.mapper_session_key].nil?

        mapper_target_id = controller.session[self.class.mapper_session_key]
        self.class.mapper_class.find(mapper_target_id, *setup.traits)
      end

      def post_step_setup
        # following line executed after successfull step 1
        controller.session[self.class.mapper_session_key] = mapper.target.id if step == 2

        setup = self.class.steps[step-2]
        return unless setup.have_setup?

        setup[controller, self]
      end

      def total_steps
        self.class.steps.length
      end

      def finished?
        step > total_steps
      end

      def increment_step!
        @step += 1
      end

      def controller_data_prepare
        controller.try(:prepare_data_for_step, step)
      end
      private :controller_data_prepare
    end
  end
end
