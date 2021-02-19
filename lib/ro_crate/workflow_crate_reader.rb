require 'ro_crate'

module ROCrate
  class WorkflowCrateReader < ::ROCrate::Reader
    def self.build_crate(entity_hash, source)
      ROCrate::WorkflowCrate.new.tap do |crate|
        crate.properties = entity_hash.delete(ROCrate::Crate::IDENTIFIER)
        crate.metadata.properties = entity_hash.delete(ROCrate::Metadata::IDENTIFIER)
        preview_properties = entity_hash.delete(ROCrate::Preview::IDENTIFIER)
        crate.preview.properties = preview_properties if preview_properties
        main_wf = entity_hash.delete(crate.properties.dig('mainEntity', '@id'))
        if main_wf && (['ComputationalWorkflow', 'Workflow'] & Array(main_wf['@type'])).any?
          crate.main_workflow = create_data_entity(crate, ROCrate::Workflow, source, main_wf)
          diagram = entity_hash.delete(main_wf.dig('image', '@id'))
          if diagram
            crate.main_workflow.diagram = create_data_entity(crate, ROCrate::WorkflowDiagram, source, diagram)
          end
          cwl = entity_hash.delete(main_wf.dig('subjectOf', '@id'))
          if cwl
            crate.main_workflow.cwl_description = create_data_entity(crate, ROCrate::WorkflowDescription, source, cwl)
          end
        else
          warn 'Main workflow not found!'
        end

        extract_data_entities(crate, source, entity_hash).each do |entity|
          crate.add_data_entity(entity)
        end

        # The remaining entities in the hash must be contextual.
        extract_contextual_entities(crate, entity_hash).each do |entity|
          crate.add_contextual_entity(entity)
        end
      end
    end
  end
end
