module ActiveRecordExtensions
  extend ActiveSupport::Concern

  # add your static(class) methods here
  module ClassMethods
    #E.g: Order.top_ten
    def top_ten
      limit(10)
    end

    def identifier_starts_with letter
      # Se ha name o code o barcode, uso uno di questi:
      column = if self.column_names.include? "name"
        :name
      elsif self.column_names.include? "title"
        :title
      elsif self.column_names.include? "code"
        :code
      elsif self.column_names.include? "barcode"
        :barcode
      end
      # Ecco la ricerca dedicata a Postgres, la facciamo multiplatform? Fatto
      query = "#{letter}%"
      match = arel_table[column].matches(query)
      where(match)
    end

    def starts_with_a
      identifier_starts_with :a
    end

    def starts_with_b
      identifier_starts_with :b
    end

    def starts_with_c
      identifier_starts_with :c
    end

    def starts_with_d
      identifier_starts_with :d
    end

    def starts_with_e
      identifier_starts_with :e
    end

    def starts_with_f
      identifier_starts_with :f
    end

    def starts_with_g
      identifier_starts_with :g
    end

    def starts_with_h
      identifier_starts_with :h
    end

    def starts_with_i
      identifier_starts_with :i
    end

    def starts_with_j
      identifier_starts_with :j
    end

    def starts_with_k
      identifier_starts_with :k
    end

    def starts_with_l
      identifier_starts_with :l
    end

    def starts_with_m
      identifier_starts_with :m
    end

    def starts_with_n
      identifier_starts_with :n
    end

    def starts_with_o
      identifier_starts_with :o
    end

    def starts_with_p
      identifier_starts_with :p
    end

    def starts_with_q
      identifier_starts_with :q
    end

    def starts_with_r
      identifier_starts_with :r
    end

    def starts_with_s
      identifier_starts_with :s
    end

    def starts_with_t
      identifier_starts_with :t
    end

    def starts_with_u
      identifier_starts_with :u
    end

    def starts_with_v
      identifier_starts_with :v
    end

    def starts_with_w
      identifier_starts_with :w
    end

    def starts_with_x
      identifier_starts_with :x
    end

    def starts_with_y
      identifier_starts_with :y
    end

    def starts_with_z
      identifier_starts_with :z
    end
  end
end
