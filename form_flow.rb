module Core
  module FlatMap
    # TODO: Write a new RDoc for flows
    class FormFlow
      # Raised when step modifiers are called with no steps defined.
      class NoStepError < RuntimeError
        # Initialize error with a message
        def initialize(name, class_name)
          super "Unable to find :#{name} step in #{class_name}"
        end
      end

      # Raised when no default mapper was mounted on the flow and the
      # step doesn't specify a mapper to work with.
      class NoMapperError < RuntimeError
      end

      # Encapsulate Step definition for each step defined within
      # a particular FormFlow.
      class Step < Struct.new(:name, :options, :mapper_extension)
        attr_accessor :before, :after

        # Return a list of traits associated with a step.
        #
        # @return [Array<Symbol>]
        def traits
          options[:traits]
        end

        # The mapper name as specified in options.
        #
        # @return [Symbol]
        def mapper_name
          options[:mapper]
        end
      end

      attr_reader :controller, :step_number, :mapper

      delegate :params, :session, :to => :controller
      delegate :mapper_extension, :traits, :to => :current_step
      delegate :target, :to => :mapper

      # Define a new step by explicitly specifying the name of the mapper
      # to use for the step and the list of traits for it. An optional
      # block acts as an extension for the mapper object.
      #
      # @param [Hash] options
      # @option [Symbol]                :mapper name of the mapper to use
      #                                         during step processing
      # @option [Symbol, Array<Symbol>] :traits traits of the mapper
      #   to be used on current step
      # @return [Array<Step>]
      def self.step(step_name, options = {}, &block)
        step_name_sym = step_name.to_sym
        steps[step_name_sym] = Step.new(step_name_sym, options, block)
      end

      # Specify a pre-processing block for the last step defined.
      # This block will be called with a controller and flow as arguments.
      #
      # @return [Proc]
      def self.before(name, &block)
        return before_each(&block) if name == :each

        find_step_by_name(name).before = block
      end

      # Specify a post-processing block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments.
      #
      # @return [Proc]
      def self.after(name, &block)
        return after_each(&block) if name == :each

        find_step_by_name(name).after = block
      end

      # Return a pre-processing setup to be performed before each step.
      # If the block is passed, it will be assigned as such setup.
      #
      # @return [Proc, nil]
      def self.before_each(&block)
        return @before_each_setup unless block_given?
        @before_each_setup = block
      end

      # Return a post-processing setup to be performed after each step.
      # If a block is passed, it will be assigned as such setup.
      #
      # @return [Proc, nil]
      def self.after_each(&block)
        return @after_each_setup unless block_given?
        @after_each_setup = block
      end

      # Find a particular step in +steps+ by its name. Will raise
      # {NoStepError} on failure.
      #
      # @param [Symbol] name
      # @return [Core::FlatMap::FormFlow::Step]
      def self.find_step_by_name(name)
        steps[name.to_sym] or raise NoStepError.new(name, self.name)
      end

      # Find particular step in +steps+ by its index. Will raise
      # {NoStepError} on failure.
      #
      # @param [Integer] index
      # @return [Core::FlatMap::FormFlow::Step]
      def self.find_step_by_index(index)
        steps.values[index - 1] or raise NoStepError.new(index, self.name)
      end

      # Return the list of steps for a class.
      #
      # @return [ActiveSupport::OrderedHash]
      def self.steps
        @steps ||= ActiveSupport::OrderedHash.new
      end

      # Return total number of steps.
      #
      # @return [Integer]
      def self.total_steps
        steps.length
      end

      # Sets the name of the mapper to use on steps by default.
      #
      # @param [Symbol] mapper_name
      # @return [Symbol]
      def self.mount(mapper_name)
        @mapper_name = mapper_name
      end

      # Return a mapper name specified by the #mount method.
      #
      # @return [Symbol, nil]
      def self.mapper_name
        @mapper_name
      end

      # Shortcut to return desired step by its name or index.
      #
      # @param [Integer, Symbol] index_or_name
      # @return [Core::FlatMap::FormFlow::Step, nil]
      def self.[](index_or_name)
        case index_or_name
        when Symbol, String
          find_step_by_name(index_or_name)
        when Fixnum, Integer
          find_step_by_index(index_or_name)
        else
          nil
        end
      end

      # Initialize a step with a +controller+ and perform additional processing
      # based on it:
      # * Get the current step from params, or default it to 1
      # * Set controller's '@flow' instance variable to +self+
      # * Perform optional initial_setup (for the first step)
      # * Prepare data for current step via special controller method
      #
      # @param [ActionController::Base] controller
      def initialize(controller, options = {})
        @controller, @options = controller, options
        @step_number = params[:step].try(:to_i) || 1
      end

      # Writer for the <tt>@step</tt> variable.
      #
      # @param [#to_i] step_number
      # @return [Integer] step number
      def goto_step_number(step_number)
        @step_number = step_number.to_i
      end

      # Return +true+ if the flow uses {PasswordTokenizer tokenizer} features
      # for the first step.
      #
      # @return [Boolean]
      def use_tokenizer?
        @options[:use_tokenizer]
      end

      # Return a tokenizer instance.
      #
      # @return [PasswordTokenizer]
      def tokenizer
        @tokenizer ||= PasswordTokenizer.new(controller.session)
      end

      # Used to perform tokenizer-specific actions on the very
      # start of the form flow.
      #
      # @return [Object]
      def initial_setup(params)
        return unless first_step?

        tokenizer.clear! if use_tokenizer?
      end

      # Process params from the submitted form via the mapper. If successful,
      # go to the next step, performing additional setup and setting the
      # <tt>@mapper</tt> to +nil+. This will force re-initialization of the
      # mapper for the context of a new step.
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

      # Call a step's +before+ processing block, if present.
      #
      # @return [Object]
      def before_step_setup
        self.class.before_each.try(:call, controller, self)
        current_step.before.try(:call, controller, self)
        tokenizer.prepare_params!(params[mapper_params_key]) if first_step? && use_tokenizer?
      end

      # Call a step's +after+ processing block, if present.
      #
      # @return [Object]
      def after_step_setup
        self.class.after_each.try(:call, controller, self)
        current_step.after.try(:call, controller, self)
        tokenizer.clear! if first_step? && use_tokenizer?
      end

      # Return an instance of the setup for the current step number.
      #
      # @return [Core::FlatMap::FormFlow::Step]
      def current_step
        self.class.find_step_by_index(step_number)
      end

      # Return the step name of the current step.
      #
      # @return [String]
      def step_name
        current_step.try(:name)
      end

      # Return an instance of mapper to be used on current step.
      #
      # @return [Core::FlatMap::Mapper]
      def mapper
        @mapper ||= fetch_mapper
      end

      # Fetch a mapper object using the list of traits defined for the step:
      # * For the first step: build a mapper with a new record
      # * For other steps: use the mapper with a record, obtained by
      #   id stored in the controller's session
      #
      # @return [Core::FlatMap::Mapper]
      def fetch_mapper
        first_step? ? build_mapper : find_mapper
      end

      # Create a mapper for a new record.
      #
      # @return [Core::FlatMap::Mapper]
      def build_mapper
        mapper_class.build(*traits, &mapper_extension)
      end

      # Create a mapper for a persisted record.
      #
      # @return [Core::FlatMap::Mapper]
      def find_mapper
        target_id = session[mapper_session_key]
        mapper_class.find(target_id, *traits, &mapper_extension)
      end

      # Fetch a mapper class based on current_mapper_name.
      #
      # @return [Class] mapper class
      def mapper_class
        "#{current_mapper_name.to_s.camelize}Mapper".constantize
      end

      # Name of the mapper to use on current step. Specified in the options on
      # the step definition. Defaults to the value specified by the #mount method.
      #
      # @return [Symbol]
      def current_mapper_name
        (current_step.mapper_name || self.class.mapper_name).tap do |name|
          raise NoMapperError unless name.present?
        end
      end

      # Fetch a key by which assignment params may be accessed
      # from +params+ of the controller and applied on the mapper.
      #
      # @return [String]
      def mapper_params_key
        "#{current_mapper_name}_mapper"
      end

      # Fetch a session key, by which the id of the mapper's target will
      # be stored in the controller's session.
      #
      # @return [Symbol]
      def mapper_session_key
        :"#{current_mapper_name}_id"
      end

      # Return the total number of steps defined in class.
      #
      # @return [Integer]
      def total_steps
        self.class.total_steps
      end

      # Return +true+ if the last step has been processed.
      #
      # @return [Boolean]
      def finished?
        step_number > total_steps
      end

      # Return +true+ if currently processing the very first step.
      #
      # @return [Boolean]
      def first_step?
        step_number == 1
      end

      # Increment <tt>@step</tt> by one.
      #
      # @return [Integer]
      def increment_step!
        @step_number += 1
      end

      # Return the view name to render for the flow.
      #
      # @return [String]
      def form_view_name
        'new'
      end
    end
  end
end
