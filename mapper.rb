module Core
  module FlatMap
    # == Mapper
    #
    # FlatMap mappers are designed to provide complex set of data, distributed over
    # associated AR models, in a simple form of plain hash. As well as accept plain
    # hash of the same format and distribute its values over deeply nested AR models.
    #
    # To achieve this goal, Mapper uses three major concepts: Mappings, Mountings and
    # Traits.
    #
    # === Mappings
    #
    # Mappings are defined view Mapper.map method. They represent a simple one-to-one
    # relation between target attribute and a mapper, extended by additional features
    # for convenience. The best way to show how they work is by example:
    #
    #   class CustomerMapper < Core::FlatMap::Mapper
    #     # When there is no need to rename attributes, they can be passed as array:
    #     map :first_name, :last_name
    #     
    #     # When hash is used, it will map field name to attribute name:
    #     map :dob => :date_of_birth
    #     
    #     # Also, additional options can be used:
    #     map :name_suffix, :format => :enum
    #     map :password, :reader => false, :writer => :assign_password
    #     
    #     # Or you can combine all definitions together if they all are common:
    #     map :first_name, :last_name, :dob => :date_of_birth, :suffix => :name_suffix, :reader => :my_custom_reader
    #   end
    #
    # When mappings are defined, one can read and write values using them:
    #
    #   mapper = CustomerMapper.find(1)
    #   mapper.read          # => {:first_name => 'John', :last_name => 'Smith', :dob => '02/01/1970'}
    #   mapper.write(params) # will assign same-looking hash of arguments
    #
    # Following options may be used when defining mappings:
    # [<tt>:format</tt>] Allows to additionally process output value on reading it. All formats are
    #                    defined within Core::FlatMap::Mapping::Reader::Formatted::Formats and
    #                    specify the actual output of the mapping
    # [<tt>:reader</tt>] Allows you to manually control reader value of a mapping, or a group of
    #                    mappings listed on definition. When String or Symbol is used, will call
    #                    a method, defined by mapper class, and pass mapping object to it. When
    #                    lambda is used, mapper's target (the model) will be passed to it.
    # [<tt>:writer</tt>] Just like with the :reader option, allows to control how value is assigned
    #                    (written). Works the same way as :reader does, but additionally value is
    #                    sent to both mapper method and lambda.
    # [<tt>:multiparam</tt>] If used, multiparam attributes will be extracted from params, when
    #                        those are passed for writing. Class should be passed as a value for
    #                        this option. Object of this class will be initialized with the arguments
    #                        extracted from params hash.
    #
    # === Mountings
    #
    # Mappers may be mounted on top of each other. This ability allows host mapper to gain all the
    # mappings of the mounted mapper, thus providing more information for external usage (both reading
    # and writing). Usually, target for mounted mapper may be obtained from association of target of
    # the host mapper itself, but may be defined manually.
    #
    #   class CustomerMapper < Core::FlatMap::Mapper
    #     map :first_name, :last_name
    #   end
    #   
    #   class CustomerAccountMapper < Core::FlatMap::Mapper
    #     map :source, :brand, :format => :enum
    #   
    #     mount :customer
    #   end
    #   
    #   mapper = CustomerAccountMapper.find(1)
    #   mapper.read # => {:first_name => 'John', :last_name => 'Smith', :source => nil, :brand => 'TLP'}
    #   mapper.write(params) # Will assign params for both CustomerAccount and Customer records
    #
    # Following options may be used when mounting mapper:
    # [<tt>:mounting_point</tt>] Allows to manually specify target for the new mapper. May be very handy
    #                            when target cannot be obviously detected or requires additional setup:
    #                            <tt>mount :title, :mounting_point => lambda{ |customer| customer.title_customers.build.build_title }</tt>
    # [<tt>:traits</tt>] Specifies list of traits to be used by mounted mapper
    #
    # === Traits
    #
    # Traits allow mappers to encapsulate named sets of additional definitions, and use them optionally
    # on mapper initialization. Everything that can be defined within the mapper may be defined within
    # the trait. In fact, from the implementation perspective traits are mappers themselves that are
    # mounted on the host mapper.
    #
    #   class CustomerAccountMapper < Core::FlatMap::Mapper
    #     map :brand, :format => :enum
    #     
    #     trait :with_email do
    #       map :source, :format => :enum
    #       
    #       mount :email_address
    #       
    #       trait :with_email_phones_residence do
    #         mount :customer, :traits => [:with_phone_numbers, :with_residence]
    #       end
    #     end
    #   end
    #   
    #   CustomerAccountMapper.find(1).read # => {:brand => 'TLP'}
    #   CustomerAccountMapper.find(1, :with_email).read # => {:brand => 'TLP', :source => nil, :email_address => 'j.smith@gmail.com'}
    #   CustomerAccountMapper.find(1, :with_email_phone_residence).read # => :brand, :source, :email_address, phone numbers,
    #                                    #:residence attributes - all will be available for reading and writing in plain hash
    #
    # === Validation
    #
    # <tt>Core::FlatMap::Mapper</tt> includes <tt>ActiveModel::Validations</tt> module, allowing each model to
    # perform its own validation routines before trying to save its target (which is usually AR model). Mapper
    # validation is very handy when mappers are used with Rails forms, since there no need to lookup for a
    # deeply nested errors hash of the AR models to extract error messages. Mapper validations will attach
    # messages to mapping names.
    #
    # Mapper validations become even more useful when used within traits, providing way of very flexible validation sets.
    #
    # === Callbacks
    #
    # Since mappers include <tt>ActiveModel::Validation</tt>, they already support ActiveSupport's callbacks.
    # Additionally, <tt>:save</tt> callbacks have been defined (i.e. there have been define_callbacks <tt>:save</tt>
    # call for <tt>Core::FlatMap::Mapper</tt>). This allows you to control flow of mapper saving:
    #
    #   set_callback :save, :before, :set_model_validation
    #   
    #   def set_model_validation
    #     target.use_validation :some_themis_validation
    #   end
    #
    # === Skipping
    #
    # In some cases, it is required to omit mapper processing after it has been created within mounting chain. If
    # <tt>skip!</tt> method is called on mapper, it will return <tt>true</tt> for <tt>valid?</tt> and <tt>save</tt>
    # method calls without performing any other operations. For example:
    #
    #   class CustomerAccountMapper < Core::FlatMap::Mapper
    #     self.target_class_name = 'CustomerAccount::Active'
    #   
    #     # some definitions
    #   
    #     trait :with_bank_account_selection do
    #       attr_reader :selected_bank_account_id
    #   
    #       mount :bank_account
    #   
    #       set_callback :validate, :before, :ignore_new_bank_account
    #       set_callback :save, :after, :update_application
    #   
    #       def ignore_new_bank_account
    #         mounting(:bank_account).skip! if bank_account_selected?
    #       end
    #   
    #       # some more definitions
    #     end
    #   end
    #
    # === Attribute Methods
    #
    # All mappers have the ability to read and write values via method calls:
    #
    #   mapper.read[:first_name] # => John
    #   mapper.first_name # => 'John'
    #   mapper.last_name = 'Smith'
    class Mapper
      # Raised when mapper is initialized with no target defined
      class NoTargetError < ArgumentError
        # Initializes exception with a describing message for +mapper+
        #
        # @param [Core::FlatMap::Mapper] mapper
        def initialize(mapper)
          super("Target object is required to initialize mapper #{mapper.inspect}")
        end
      end

      extend ActiveSupport::Autoload

      autoload :Mapping
      autoload :Mounting
      autoload :Traits
      autoload :Factory
      autoload :AttributeMethods
      autoload :ModelMethods
      autoload :Skipping

      include Mapping
      include Mounting
      include Traits
      include AttributeMethods
      include ActiveModel::Validations
      include ModelMethods
      include Skipping

      attr_reader :target, :traits
      attr_accessor :owner, :name

      # Initializes +mapper+ with +target+ and +traits+, which are
      # used to fetch proper list of mounted mappers. Raises error
      # if target is not specified.
      #
      # @param [Object] target Target of mapping
      # @param [*Symbol] traits List of traits
      # @raise [Core::FlatMap::Mapper::NoTargetError]
      def initialize(target, *traits)
        raise NoTargetError.new(self) unless target.present?

        @target, @traits = target, traits

        if block_given?
          singleton_class.trait :extension, &Proc.new
        end
      end

      # Return a simple string representation of +mapper+. Done so to
      # avoid really long inspection of internal objects (target -
      # usually AR model, mountings and mappings)
      # @return [String]
      def inspect
        to_s
      end

      # Return +true+ if +mapper+ is owned. This means that current
      # mapper is actually a trait. Thus, it is a part of an owner
      # mapper.
      #
      # @return [Boolean]
      def owned?
        owner.present?
      end
    end
  end
end
