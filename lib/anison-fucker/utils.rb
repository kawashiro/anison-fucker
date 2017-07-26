##
# Some useful crap
##


module AnisonFucker
  module Utils
    # Convert hash keys to symbol
    #   hash    Hash
    def keys_to_sym(hash)
      Hash[hash.map { |k, v| [k.to_sym, v] }]
    end
  end
end
