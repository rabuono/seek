require 'test_helper'

class CollectionTest < ActiveSupport::TestCase
  fixtures :all

  test 'project' do
    person = Factory(:person)
    p = person.projects.first
    s = Factory(:collection, projects: [p], contributor:person)
    assert_equal p, s.projects.first
  end

  test 'to_rdf' do
    person = Factory(:person)
    person.add_to_project_and_institution(Factory(:project),person.institutions.first)
    object = Factory(:populated_collection, description: 'An excellent Collection', projects: person.projects, contributor: person)
    Factory :assets_creator, asset: object, creator: Factory(:person)

    object = Collection.find(object.id)
    refute_empty object.creators

    rdf = object.to_rdf

    RDF::Reader.for(:rdfxml).new(rdf) do |reader|
      assert reader.statements.count > 1
      assert_equal RDF::URI.new("http://localhost:3000/collections/#{object.id}"), reader.statements.first.subject

      #check for OPSK-1281 - where the creators weren't appearing
      assert_includes reader.statements.collect(&:predicate),"http://jermontology.org/ontology/JERMOntology#hasCreator"
      assert_includes reader.statements.collect(&:predicate),"http://rdfs.org/sioc/ns#has_creator"
    end
  end

  test 'title trimmed' do
    collection = Factory(:collection, title: ' test collection')
    assert_equal('test collection', collection.title)
  end

  test 'validation' do
    asset = Collection.new title: 'fred', projects: [projects(:sysmo_project)], policy: Factory(:private_policy)
    assert asset.valid?

    asset = Collection.new projects: [projects(:sysmo_project)], policy: Factory(:private_policy)
    assert !asset.valid?
  end

  test 'avatar key' do
    assert Factory(:collection).avatar_key
    refute Factory(:collection).use_mime_type_for_avatar?
  end

  test 'policy defaults to system default' do
    with_config_value 'default_all_visitors_access_type', Policy::NO_ACCESS do
      collection = Factory.build(:collection)
      refute collection.persisted?
      collection.save!
      collection.reload
      assert collection.valid?
      assert collection.policy.valid?
      assert_equal Policy::NO_ACCESS, collection.policy.access_type
      assert collection.policy.permissions.blank?
    end
  end

  test 'assign projects' do
    person = Factory(:person)
    project = person.projects.first
    User.with_current_user(person.user) do
      collection = Factory(:collection, projects: [project], contributor: person)
      person.add_to_project_and_institution(Factory(:project), person.institutions.first)
      projects = person.projects
      assert_equal 2,projects.count
      collection.update_attributes(project_ids: projects.map(&:id))
      collection.save!
      collection.reload
      assert_equal projects.sort, collection.projects.sort
    end
  end

  test 'test uuid generated' do
    x = Factory.build(:collection)
    assert_nil x.attributes['uuid']
    x.save
    assert_not_nil x.attributes['uuid']
  end

  test "uuid doesn't change" do
    x = Factory.build(:collection)
    x.save
    uuid = x.attributes['uuid']
    x.save
    assert_equal x.uuid, uuid
  end

  test 'contributing user' do
    collection = Factory :collection, contributor: Factory(:person)
    assert collection.contributor
    assert_equal collection.contributor.user, collection.contributing_user
  end

  test 'collection assets' do
    collection = Factory(:collection)
    sop = Factory(:sop)
    data_file = Factory(:data_file)
    document = Factory(:document)
    assert_empty collection.items
    assert_empty collection.assets

    assert_difference('CollectionItem.count', 3) do
      collection.items.create!(asset: sop)
      collection.items.create!(asset: data_file)
      collection.items.create!(asset: document)
    end

    assert_includes collection.assets, sop
    assert_includes collection.assets, data_file
    assert_includes collection.assets, document
  end

  test 'collection assets are unique' do
    collection = Factory(:collection)
    sop = Factory(:sop)
    assert collection.items.create(asset: sop)

    assert_no_difference('CollectionItem.count') do
      item = collection.items.create(asset: sop)
      assert item.errors.added?(:asset_id, :taken, value: sop.id)
    end
  end

  test 'collection items destroyed with collection' do
    collection = Factory(:populated_collection)

    assert_difference('Collection.count', -1) do
      assert_difference('CollectionItem.count', -1) do
        disable_authorization_checks { collection.destroy }
      end
    end
  end
end