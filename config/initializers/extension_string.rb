class String
    def to_bool
        return true if self.downcase == "true"
        false
    end
end