class Current < ActiveSupport::CurrentAttributes
  attribute :session, :group
  delegate :user, to: :session, allow_nil: true
end
