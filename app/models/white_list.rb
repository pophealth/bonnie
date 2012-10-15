class WhiteList < ValueSet
  def self.is_available?
    WhiteList.all.size > 0 ? true : false
  end
end