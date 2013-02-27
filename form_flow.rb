module Core
  module FlatMap
    # TODO: Write a new RDoc for flows
    class FormFlow
      # Raised when step modifiers are called with no steps defined
      class NoStepsError < RuntimeError
        # Initialize error with a message
        def initialize
          super '#before and #after methods require at least one step to be defined via #step method call'
        end
      end

      # Raised when no default mapper was mounted on the flow and
      # step doesn't specify a mapper to work with
      class NoMapperError < RuntimeError
      end

      # Encapsulates Step definition for each step defined within
      # particular FormFlow
      class Step < Struct.new(:options, :mapper_extension)
        attr_accessor :before, :after

        # Return list of traits associated with a step
        #
        # @return [Array<Symbol>]
        def traits
          options[:traits]
        end

        # Mapper name as specified in options
        #
        # @return [Symbol]
        def mapper_name
          options[:mapper]
        end
      end

      attr_reader :controller, :step, :mapper

      delegate :params, :session, :to => :controller
      delegate :mapper_extension, :traits, :to => :current_step
      delegate :target, :to => :mapper

      # Define a new step by explicitly specifying name of the mapper
      # to use for the step and the list of traits for it. Optional
      # block acts as an extension for the mapper object.
      #
      # @param [Hash] options
      # @option [Symbol]                :mapper name of the mapper to use
      #                                         during step processing
      # @option [Symbol, Array<Symbol>] :traits traits of the mapper
      #   to be used on current step
      # @return [Array<Step>]
      def self.step(options = {}, &block)
        steps.push Step.new(options, block)
      end

      # Specifies a preprocessing block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments
      #
      # @return [Proc]
      def self.before(&block)
        raise NoStepsError if steps.empty?
        steps.last.before = block
      end

      # Specifies a postprocessinf block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments
      #
      # @return [Proc]
      def self.after(&block)
        raise NoStepsError if steps.empty?
        steps.last.after = block
      end

      # Return list of steps of a class
      #
      # @return [Array<Step>]
      def self.steps
        @steps ||= []
      end

      # Sets name of the mapper to use on steps by default
      #
      # @param [Symbol] mapper_name
      # @return [Symbol]
      def self.mount(mapper_name)
        @mapper_name = mapper_name
      end

      # Return a mapper name specified by #mount method
      #
      # @return [Symbol, nil]
      def self.mapper_name
        @mapper_name
      end

      # Initialize step with a +controller+ and perform additional processing
      # based on it:
      # * Get the current step from params, or defualt it to 1
      # * Set controller's '@flow' instance variable to +self+
      # * Perform optional intial_setup (for the first step)
      # * Preperate data for current step via specia controller method
      #
      # @param [ActionController::Base] controller
      def initialize(controller, options = {})
        @controller, @options = controller, options
        @step = params[:step].try(:to_i) || 1
      end

      # Return true if flow uses {PasswordTokenizer tokenizer} features for the first step
      #
      # @return [Boolean]
      def use_tokenizer?
        @options[:use_tokenizer]
      end

      # Return tokenizer instance
      #
      # @return [PasswordTokenizer]
      def tokenizer
        @tokenizer ||= PasswordTokenizer.new(controller.session)
      end

      # Used to perform tokenizer-specific actions on the very
      # start of the form flow.
      #
      # @return [Object]
      def initial_setup
        return unless first_step?

        tokenizer.clear! if use_tokenizer?
      end

      # Process params from submitted form via mapper. If successfull,
      # will go to the next step, performing additional setup and
      # setting <tt>@mapper</tt> to nil - this will force re-initialization
      # of mapper for a context of a new step
      #
      # @return [Object, nil]
      def process
        before_step_setup
        if mapper.apply(params[mapper_params_key])
          after_step_setup
          increment_step!
          @mapper = nil unless finished?
          true
        else
          tokenizer.tokenize_attributes!(mapper) if first_step? && use_tokenizer?
        end
      end

      # Calls a step's before processing block, if present
      #
      # @return [Object]
      def before_step_setup
        current_step.before.try(:call, controller, self)
        tokenizer.prepare_params!(params[mapper_params_key]) if first_step? && use_tokenizer?
      end

      # Calls a step's after processing block, if present
      #
      # @return [Object]
      def after_step_setup
        current_step.after.try(:call, controller, self)
        tokenizer.clear! if first_step? && use_tokenizer?
      end

      # Return instance of the setup for the current step number
      #
      # @return [Core::FlatMap::FormFlow::Step]
      def current_step
        self.class.steps[step - 1]
      end

      # Return instance of mapper to be used on current step
      #
      # @return [Core::FlatMap::Mapper]
      def mapper
        @mapper ||= fetch_mapper
      end


      # Fetches a mapper object using list of traits defined for the step:
      # * For the first step will build a mapper with a new record
      # * For other steps will use mapper with a record, obtained by
      #   id stored in controller's session
      #
      # @return [Core::FlatMap::Mapper]
      def fetch_mapper
        first_step? ? build_mapper : find_mapper
      end

      # Create a mapper for a new record
      #
      # @return [Core::FlatMap::Mapper]
      def build_mapper
        mapper_class.build(*traits, &mapper_extension)
      end

      # Create a mapper for a persisted record
      #
      # @return [Core::FlatMap::Mapper]
      def find_mapper
        target_id = session[mapper_session_key]
        mapper_class.find(target_id, *traits, &mapper_extension)
      end

      # Fetch a mapper class based on current_mapper_name
      #
      # @return [Class] mapper class
      def mapper_class
        "#{current_mapper_name.to_s.camelize}Mapper".constantize
      end

      # Name of the mapper to use on current step. Specified in options
      # on step definition, and defaults to value specified by #mount method
      #
      # @return [Symbol]
      def current_mapper_name
        (current_step.mapper_name || self.class.mapper_name).tap do |name|
          raise NoMapperError unless name.present?
        end
      end

      # Fetch a key by which assignment params may be accessed
      # from +params+ of the controller and applied on the mapper
      #
      # @return [String]
      def mapper_params_key
        "#{current_mapper_name}_mapper"
      end

      # Fetch a session key, by which id of the mapper's target will
      # be stored in controller's session
      #
      # @return [Symbol]
      def mapper_session_key
        :"#{current_mapper_name}_id"
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

      # Return +true+ if currently processing the very first step
      #
      # @return [Boolean]
      def first_step?
        step == 1
      end

      # Increment <tt>@step</tt> by one
      #
      # @return [Integer]
      def increment_step!
        @step += 1
      end

      # Return view name to render for flow
      #
      # @return [String]
      def form_view_name
        'new'
      end
    end
  end
end
