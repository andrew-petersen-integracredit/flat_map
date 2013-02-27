module Core
  module FlatMap
    # TODO: Write a new RDoc for flows
    class FormFlow
      # Raised when step modifiers are called with no steps defined
      class NoStepError < RuntimeError
        # Initialize error with a message
        def initialize(name, class_name)
          super "Unable to find :#{name} step in #{class_name}"
        end
      end

      # Raised when no default mapper was mounted on the flow and
      # step doesn't specify a mapper to work with
      class NoMapperError < RuntimeError
      end

      # Encapsulates Step definition for each step defined within
      # particular FormFlow
      class Step < Struct.new(:name, :options, :mapper_extension)
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
      def self.step(step_name, options = {}, &block)
        steps.push Step.new(step_name, options, block)
      end

      # Specifies a preprocessing block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments
      #
      # @return [Proc]
      def self.before(name, &block)
        return before_each(&block) if name == :each

        find_step_by_name(name).before = block
      end

      # Specifies a postprocessinf block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments
      #
      # @return [Proc]
      def self.after(name, &block)
        return after_each(&block) if name == :each

        find_step_by_name(name).after = block
      end

      # Return pre-processing setup to be performed before each step.
      # If the block is passed, it will be assigned as such setup.
      #
      # @return [Proc, nil]
      def self.before_each(&block)
        return @before_each_setup unless block_given?
        @before_each_setup = block
      end

      # Return post-processing setup to be performed after each step.
      # If the block is passed, it will be assigned as such setup.
      #
      # @return [Proc, nil]
      def self.after_each(&block)
        return @after_each_setup unless block_given?
        @after_each_setup = block
      end

      # Finds particular step in +steps+ by its name. Will raise
      # {NoStepError} on failure
      #
      # @param [Symbol] name
      # @return [Core::FlatMap::FormFlow::Step]
      def self.find_step_by_name(name)
        steps.find{ |step| step.name == name }.tap do |step|
          raise NoStepError.new(name, self.name) unless step.present?
        end
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

      # Shortcut to return desired step by it's name or index
      #
      # @param [Integer, Symbol] index_or_name
      # @return [Core::FlatMap::FormFlow::Step, nil]
      def self.[](index_or_name)
        case index_or_name
        when Symbol
          find_step_by_name(index_or_name)
        when Integer
          steps[index_or_name]
        else
          nil
        end
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

      # Writer for the <tt>@step</tt> variable.
      #
      # @param [#to_i] step_number
      # @return [Integer] step number
      def goto_step(step_number)
        @step = step_number.to_i
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

      # Process params from submitted form via mapper. If successful,
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
          false
        end
      end

      # Calls a step's before processing block, if present
      #
      # @return [Object]
      def before_step_setup
        self.class.before_each.try(:call, controller, self)
        current_step.before.try(:call, controller, self)
        tokenizer.prepare_params!(params[mapper_params_key]) if first_step? && use_tokenizer?
      end

      # Calls a step's after processing block, if present
      #
      # @return [Object]
      def after_step_setup
        self.class.after_each.try(:call, controller, self)
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
