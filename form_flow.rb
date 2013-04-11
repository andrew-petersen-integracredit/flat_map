module Core
  module FlatMap
    # == FormFlow
    #
    # FormFlow classes are used as integration piece between mappers and controllers.
    # Idea behind them is to define set of named steps, each of which describes
    # traits and other options for a specific form. However, ability to define
    # callbacks to be executed before and after each step provides more functionality
    # than simple mapper-controller integration.
    #
    # === Initialization
    #
    # FormFlow objects are initialized with a controller and a set of options:
    #
    # [<tt>:step_name</tt>]     Specify a step name to by used by flow in current action.
    # [<tt>:use_tokenizer</tt>] Allows to specify whether or not use PasswordTokenizer
    #                           feature for processing first step of the form. This
    #                           is used more like helper to move repeated code out
    #                           of controller.
    #
    # === Mapper
    #
    # Each flow should define mapper it will work with via +mount+ method. However,
    # each particular step defined may overload this setting via <tt>:mapper</tt>
    # option. The block used at step definition will act as a mapper extension.
    # Thus, additional mappings, mountings or callbacks may be defined there.
    #
    # === Steps
    #
    # Each step within a flow is a named set of options, used to build a mapper
    # for subsequent params processing or building a form in a view. A step is
    # defined by a name, a set of options and an optional block.
    #
    # [<tt>:mapper</tt>] Allows to overload mapper class used by a flow on current
    #                    step.
    # [<tt>:traits</tt>] Allows to specify a list of traits to be applied to a
    #                    mapper on current step.
    #
    # The block, if present, is used as an extension for the mapper used on the
    # current step.
    #
    # === Callbacks
    #
    # To provide additional pre- and post-step processing, one may define callbacks
    # for each step. Since steps are named, each callback is defined via +before+
    # or +after+ method, and a block of code with arity of 2. Controller and a
    # flow itself are passed to this block on call.
    #
    # Additionally, <tt>:each</tt> may be used instead of step name to define a
    # callback to be executed for each step.
    #
    # === Example
    #
    #   class Registration::FourStepFlow < Core::FlatMap::FormFlow
    #     mount :customer_account
    #     
    #     step :first, :traits => :password_validation do
    #       validates_with TexasDisclosuresValidator, :source => :application_state
    #       
    #       mount :email_address
    #       mount :application
    #       mount :customer, :traits => :phone_numbers
    #     end
    #     
    #     before :first do |controller, flow|
    #       flow.mapper.write :brand => Customer.current_brand
    #     end
    #     
    #     after :first do |controller, flow|
    #       controller.session[:customer_account_id] = flow.target.id
    #       controller.session[:customer_id]         = flow.target.customer.id
    #       controller.log_in_current_customer_account(flow.target.id)
    #     end
    #     
    #     step :second do
    #       mount :customer, :traits => :vehicle_selection
    #       
    #       set_callback :save, :after, :assign_application_title
    #       
    #       # Associate the title we just created to this application
    #       def assign_application_title
    #         application = target.applications.latest
    #         assign_title(application)
    #       end
    #     end
    #     
    #     # more definitions
    #     
    #     after :each do |controller, flow|
    #       flow.mapper.target.increment_registration_step!(registration_flow_class, flow.step_number)
    #     end
    #   end
    class FormFlow
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

      class_attribute :mapper_name, :before_each, :after_each

      attr_reader :controller, :step_name, :mapper

      delegate :params, :session, :to => :controller
      delegate :mapper_extension, :traits, :to => :current_step
      delegate :target, :to => :mapper

      # Callback to clone steps for inherited FormFlow.
      def self.inherited(subclass)
        return unless self < Core::FlatMap::FormFlow
        subclass.steps = steps.dup
      end

      # Define a new step by explicitly specifying the name of the mapper
      # to use for the step and the list of traits for it. An optional
      # block acts as an extension for the mapper object.
      #
      # @param [Symbol] step_name
      # @param [Hash]   options
      # @option [Symbol]                :mapper name of the mapper to use
      #                                         during step processing
      # @option [Symbol, Array<Symbol>] :traits traits of the mapper
      #   to be used on current step
      # @return [Array<Step>]
      def self.step(step_name, options = {}, &block)
        steps[step_name] = Step.new(step_name, options, block)
      end

      # Specify a pre-processing block for the last step defined.
      # This block will be called with a controller and flow as arguments.
      #
      # @return [Proc]
      def self.before(name, &block)
        return self.before_each = block if name == :each

        steps[name].before = block
      end

      # Specify a post-processing block for the last step defined.
      # This block will be called with a controller and flow
      # as arguments.
      #
      # @return [Proc]
      def self.after(name, &block)
        return self.after_each = block if name == :each

        steps[name].after = block
      end

      # Return the list of steps for a class.
      #
      # @return [ActiveSupport::OrderedHash]
      def self.steps
        @steps ||= ActiveSupport::OrderedHash.new
      end

      # Writer for @steps
      #
      # @return [ActiveSupport::OrderedHash]
      def self.steps=(value)
        @steps = value
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
        self.mapper_name = mapper_name
      end

      # Shortcut to return desired step by its name or index.
      #
      # @param [String, Symbol] step_name
      # @return [Core::FlatMap::FormFlow::Step, nil]
      def self.[](step_name)
        steps[step_name]
      end

      # Rename one or more steps. Takes a hash of form {old_name => new_name}
      #
      # @param [Hash] hash
      # @return [Hash]
      def self.rename_step(hash)
        hash.each do |old_name, new_name|
          steps[new_name] = steps.delete(old_name)
        end
      end
      private_class_method :rename_step

      # Initialize a step with a +controller+ and a set of options
      #
      # @param [ActionController::Base] controller
      # @param [Hash] options
      def initialize(controller, options = {})
        @controller, @options = controller, options
        @step_name = options[:step_name].try(:to_sym)
      end

      # Writer for the <tt>@step_name</tt> variable.
      #
      # @param [#to_sym] step_name
      # @return [String, Symbol]
      def goto(step_name)
        @mapper = nil
        @step_name = step_name.to_sym
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
        before_each.try(:call, controller, self)
        current_step.before.try(:call, controller, self)
        tokenizer.prepare_params!(params[mapper_params_key]) if first_step? && use_tokenizer?
      end

      # Call a step's +after+ processing block, if present.
      #
      # @return [Object]
      def after_step_setup
        after_each.try(:call, controller, self)
        current_step.after.try(:call, controller, self)
        tokenizer.clear! if first_step? && use_tokenizer?
      end

      # Return an instance of the setup for the current step number.
      #
      # @return [Core::FlatMap::FormFlow::Step]
      def current_step
        self.class[step_name]
      end

      # Return +true+ if there was a step definition for a passed +step_name+
      #
      # @param [#to_sym] step_name
      # @return [Boolean]
      def step_defined?(step_name)
        self.class.steps.key?(step_name.to_sym)
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

      # Return +true+ if +step_name+ corresponds to name of the first step
      # defined by flow.
      #
      # @return [Boolean]
      def first_step?
        self.class.steps.keys[0] == step_name
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

      # Return the view name to render for the flow.
      #
      # @return [String]
      def form_view_name
        'new'
      end
    end
  end
end
