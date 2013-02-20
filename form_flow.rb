module Core
  module FlatMap
    # FormFlow classes are used as helper classes to use various setup of mappers
    # during multi-step form submission process in your controller. Originally,
    # each form flow uses the same mapper object on every step and is highly
    # coupled with the controller.
    #
    # Each form flow class should define a mapper it will work with via <tt>:mount</tt>
    # method call and a set of steps via <tt>:step</tt> method calls.
    #
    # Each step within a flow is defined as a set of traits to be applied to
    # mapper object created at a this step, provided by an optional callback block
    # that will be called if step was successfully submitted. Controller and flow
    # object will be passed to this block
    #
    # Example
    #
    #   class MyRegFlow < Core::FlatMap::FormFlow
    #     mount :customer_account
    #   
    #     initially do |controller, flow|
    #       flow.mapper.write \
    #         :brand                 => Customer.current_brand,
    #         :password              => 'secret',
    #         :password_confirmation => 'secret'
    #     end
    #   
    #     step :traits => :with_email_phones_residence do |controller, flow|
    #       # customer_account_id is assigned automatically
    #       controller.session[:customer_id] = flow.customer_account.customer.id
    #     end
    #   
    #     step :traits => :with_vehicle
    #   
    #     step :traits => :with_employment_work_phone_ssn
    #   
    #     step :traits => :with_new_bank_account do |controller, flow|
    #       controller.session[:registered] = true
    #     end
    #   end
    class FormFlow
      # Encapsulates Step definition for each step defined within
      # particular FormFlow
      class StepSetup < Struct.new(:options, :setup)
        delegate :call, :[], :to => :setup

        # Return +true+ if step was defined with additional
        # setup block
        #
        # @return [Boolean]
        def have_setup?
          setup.present?
        end

        # Return list of traits associated with a step
        #
        # @return [Array<Symbol>]
        def traits
          options[:traits]
        end
      end

      attr_reader :controller, :step, :mapper

      delegate :params, :to => :controller

      # Specify a single top-level mapper name, instance of which
      # will be used during whole flow
      #
      # @param [Symbol] mapper_name
      # @return [Proc] return value is not used
      def self.mount(mapper_name)
        @mapper_name = mapper_name
        define_method(mapper_name){ mapper.target }
      end

      # Define a new step by explicitly specifying list of traits
      # for the mapper as +traits+ option and an optional
      # setup block which is executed when step is successfully
      # processed
      #
      # @param [Hash] options
      # @option [Symbol, Array<Symbol>] :traits traits of the mapper
      #   to be used on current step
      # @return [Array<StepSetup>]
      def self.step(options, &block)
        steps.push StepSetup.new(options, block)
      end

      # Saves a block as a setup for first step
      #
      # @return [Proc]
      def self.initially(&block)
        return @initial_setup unless block_given?
        @initial_setup = block
      end

      # Return list of steps of a class
      #
      # @return [Array<StepSetup>]
      def self.steps
        @steps ||= []
      end

      # Fetch a mapper class based on mounted mapper_name
      #
      # @return [Class] mapper class
      def self.mapper_class
        "#{@mapper_name.to_s.camelize}Mapper".constantize
      end

      # Fetch a key by which assignment params may be accessed
      # from +params+ of the controller and applied on the mapper
      #
      # @return [String]
      def self.mapper_params_key
        "#{@mapper_name}_mapper"
      end

      # Fetch a session key, by which id of the mapper's target will
      # be stored in controller's session
      #
      # @return [Symbol]
      def self.mapper_session_key
        :"#{@mapper_name}_id"
      end

      # Initialize step with a +controller+ and perform additional processing
      # based on it:
      # * Get the current step from params, or defualt it to 1
      # * Set controller's '@flow' instance variable to +self+
      # * Perform optional intial_setup (for the first step)
      # * Preperate data for current step via specia controller method
      #
      # @param [ActionController::Base] controller
      def initialize(controller)
        @controller = controller
        @step = params[:step].try(:to_i) || 1
        controller.instance_variable_set(:@flow, self)
        initial_setup
        controller_data_prepare
      end

      # Calls a initialization setup block, if present, for the first
      # step, passing +controller+ and +self+ to it
      #
      # @return [Object]
      def initial_setup
        return unless step == 1
        setup = self.class.initially
        setup[controller, self] if setup.present?
      end

      # Calls setup block of the last step defined, if present, passing
      # +controller+ and +self+ to it
      #
      # @return [Object]
      def final_setup
        setup = self.class.steps.last
        setup[controller, self] if setup.present?
      end

      # Fetch and return mapper object.
      #
      # @return [Core::FlatMap::Mapper]
      def mapper
        @mapper ||= fetch_mapper
      end

      # Process params from submitted form via mapper. If successfull,
      # will go to the next step, performing additional setup and
      # setting <tt>@mapper</tt> to nil - this will force re-initialization
      # of mapper for a context of a new step
      #
      # @return [Object, nil]
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

      # Fetches a mapper object using list of traits defined for the step:
      # * For the first step will build a mapper with a new record
      # * For other steps will use mapper with a record, obtained by
      #   id stored in controller's session
      #
      # @return [Core::FlatMap::Mapper]
      def fetch_mapper
        setup = self.class.steps[step-1]
        return self.class.mapper_class.build(*setup.traits) if step == 1

        mapper_target_id = controller.session[self.class.mapper_session_key]
        self.class.mapper_class.find(mapper_target_id, *setup.traits)
      end

      # Executed on a successfull transition from a step to the next one.
      # Always assigns a mapper's target id to the controller's session
      # after step one
      #
      # @return [Object, nil]
      def post_step_setup
        # following line executed after successfull step 1
        controller.session[self.class.mapper_session_key] = mapper.target.id if step == 2

        setup = self.class.steps[step-2]
        return unless setup.have_setup?

        setup[controller, self]
      end

      # Return total number of steps defined in class
      #
      # @return [Integer]
      def total_steps
        self.class.steps.length
      end

      # Return +true+ if the last step has been processed
      #
      # @return [Boolean]
      def finished?
        step > total_steps
      end

      # Increment <tt>@step</tt> by one
      #
      # @return [Integer]
      def increment_step!
        @step += 1
      end

      # If controller responds to +prepare_data_for_step+ method,
      # will call it, passing current +step+
      #
      # @return [Object]
      def controller_data_prepare
        controller.try(:prepare_data_for_step, step)
      end
      private :controller_data_prepare
    end
  end
end
