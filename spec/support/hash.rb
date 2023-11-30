class Hash
  def self.stringify_keys(h)
    h.is_a?(Hash) ? h.collect{|k,v| [k.to_s, stringify_keys(v)]}.to_h : h
  end

  def stringify_keys
    self.class.stringify_keys(self)
  end
end
