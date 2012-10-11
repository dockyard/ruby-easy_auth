module EasyAuth::Models::Account
  class NoIdentityUsernameError < StandardError; end
  def self.included(base)
    base.class_eval do
      unless respond_to?(:identity_username_attribute)
        def self.identity_username_attribute
          if column_names.include?('username')
            :username
          elsif column_names.include?('email')
            :email
          else
            raise EasyAuth::Models::Account::NoIdentityUsernameError, 'your model must have either a #username or #email attribute. Or you must override the .identity_username_attribute class method'
          end
        end
      end

      def identity_username_attribute
        self.send(self.class.identity_username_attribute)
      end

      has_one :identity, :as => :account, :dependent => :destroy
      before_create :setup_password_identity, :if => :should_run_password_identity_validations?
      before_update :update_password_identity, :if => :should_run_password_identity_validations?

      attr_accessor :password
      validates :password, :presence => { :on => :create, :if => :should_run_password_identity_validations? }, :confirmation => true
      attr_accessible :password, :password_confirmation
      validates identity_username_attribute, :presence => true, :if => :should_run_password_identity_validations?
    end
  end

  def should_run_password_identity_validations?
    (self.new_record? && self.password.present?) || (EasyAuth.password_identity_model === self.identity)
  end

  def generate_session_token!
    token = BCrypt::Password.create("#{id}-session_token-#{DateTime.current}")
    self.update_column(:session_token, token)
    self.session_token
  end

  def set_session(session)
    session[:session_token] = generate_session_token!
    session[:account_class] = self.class.to_s
  end

  private

  def setup_password_identity
    self.identity = EasyAuth.password_identity_model.new(identity_attributes)
  end

  def update_password_identity
    identity.update_attributes(identity_attributes)
  end

  def identity_attributes
    { :username => self.identity_username_attribute, :password => self.password, :password_confirmation => self.password_confirmation }
  end
end
