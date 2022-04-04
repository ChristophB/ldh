class Role < ApplicationRecord
  belongs_to :person, required: false
  belongs_to :role_type, required: false
  belongs_to :scope, polymorphic: true, optional: true

  validates :person_id, uniqueness: { scope: [:role_type_id, :scope_id, :scope_type] }
  validate :role_type_matches_scope, if: -> { role_type.present? }
  validate :scope_allows_person, if: -> { scope.present? }

  after_commit :queue_update_auth_table

  def self.with_role_key(key)
    joins(:role_type).where(role_types: { key: key })
  end

  def scope_title
    I18n.t(scope.nil? ? 'roles.scopes.system' : scope_type.underscore)
  end

  private

  def role_type_matches_scope
    if scope&.class&.name != role_type.scope
      errors.add(:role_type, "is not a valid #{scope_title} role.")
    end
  end

  def scope_allows_person
    if scope.is_a?(Project) && !scope.people.include?(person)
      errors.add(:person, "does not belong to this #{scope_title}.")
    end
  end

  def queue_update_auth_table
    AuthLookupUpdateQueue.enqueue(person) if person
  end
end
