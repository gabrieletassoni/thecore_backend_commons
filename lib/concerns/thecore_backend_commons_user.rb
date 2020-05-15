require 'active_support/concern'

module ThecoreBackendCommonsUser
    extend ActiveSupport::Concern
    
    included do
        devise :rememberable
        devise :timeoutable, timeout_in: 30.minutes 
        validates :username, uniqueness: { case_sensitive: false }, presence: true, length: { in: 4..15 }
        validates_format_of :username, with: /\A[a-zA-Z0-9]*\z/, on: :create, message: "can only contain letters and digits"
    end
end
