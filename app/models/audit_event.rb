class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :target, polymorphic: true, optional: true

  # Rails 8 enum signature: enum(name, values = nil, **options)
  enum :action,
       { login: 'login',
         dataset_created: 'dataset_created',
         query_created: 'query_created' },
       suffix: true
end
