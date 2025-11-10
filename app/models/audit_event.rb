class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :target, polymorphic: true, optional: true

  # Rails 8 enum signature: enum(name, values = nil, **options)
  enum :action,
       { login: "login",
         dataset_created: "dataset_created",
         query_created: "query_created",
         query_executed: "query_executed",
         query_failed: "query_failed",
         privacy_budget_exhausted: "privacy_budget_exhausted",
         data_room_created: "data_room_created",
         data_room_invitation_sent: "data_room_invitation_sent",
         data_room_attested: "data_room_attested",
         data_room_executed: "data_room_executed",
         data_room_execution_failed: "data_room_execution_failed" },
       suffix: true
end
