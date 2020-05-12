module ThecoreBackendCommonsUser
    extend ActiveSupport::Concern
    
    included do
        devise :rememberable
        devise :trackable
        devise :validatable
        devise :timeoutable, timeout_in: 30.minutes 
    end
end
