class FormSerializer
  def is_a_number?(string)
    string.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) == nil ? false : true
  end

  def serialize_params(original, serialized={})
    if original.respond_to?(:keys)
      original.keys.each do |key|
        current_attribute = original[key]
        if current_attribute.respond_to?(:keys)
          if serialized[key.to_sym].nil?
            serialized[key.to_sym] = Array.new
          end
          current_attribute.each do |i|
            # form params have numbers as keys, if nested forms recurse
            if (self.is_a_number?(i[0]) && i[1].class != String)
              # recurse
              serialized[key.to_sym] << serialize_params(i[1])
            elsif i[1].class == String
              # handles arrays of forms (like codes)
              serialized[key.to_sym] << i[1]
            end
          end
        else
          # assign regular attribute
          serialized[key.to_sym] = current_attribute
        end
      end
      return serialized
    end
  end
end