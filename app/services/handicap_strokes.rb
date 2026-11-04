class HandicapStrokes
  def self.for(allowance, stroke_index)
    allowance.div(18) + (stroke_index <= allowance % 18 ? 1 : 0)
  end
end
