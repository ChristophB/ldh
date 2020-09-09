module Ga4gh
  module Trs
    module V2
      class ToolsController < TrsBaseController
        before_action :paginate_and_filter, only: [:index]
        before_action :get_tool, only: [:show]

        def show
          respond_with(@tool, adapter: :attributes)
        end

        def index
          respond_with(@tools, adapter: :attributes)
        end

        private

        def get_tool
          workflow = Workflow.find(params[:id])
          respond_with({}, adapter: :attributes, status: :forbidden) unless workflow.can_view?
          @tool = Ga4gh::Trs::V2::Tool.new(workflow)
        end

        def paginate_and_filter
          @offset = tools_index_params[:offset]&.to_i
          @limit = tools_index_params[:limit]&.to_i || 1000

          # Filtering
          workflows = Workflow.includes(:projects).includes(:workflow_class).includes(:creators).authorized_for('view')
          workflows = workflows.where(id: tools_index_params[:id]) if tools_index_params[:id].present?
          workflows = workflows.where(title: tools_index_params[:name]) if tools_index_params[:name].present?
          workflows = workflows.where(description: tools_index_params[:description]) if tools_index_params[:description].present?
          workflows = workflows.where('1=0') if tools_index_params[:toolClass].present? && tools_index_params[:toolClass] == ToolClass::WORKFLOW.name
          if tools_index_params[:descriptorType].present?
            class_title = ToolVersion::DESCRIPTOR_TYPE_MAPPING.invert[tools_index_params[:descriptorType]]
            if class_title
              workflows = workflows.where(workflow_classes: { title: class_title })
            end
          end
          workflows = workflows.where(projects: { title: tools_index_params[:organization] }) if tools_index_params[:organization].present?
          workflows = workflows.where('1=0') if tools_index_params[:checker].present? && tools_index_params[:checker].to_s.downcase != 'false'
          if tools_index_params[:author].present?
            people = Person.all.select { |p| p.name == tools_index_params[:author] }.map(&:id)
            workflows = workflows.where(people: { id: people })
          end
          # Not implemented:
#          tools_index_params[:alias]
#          tools_index_params[:registry]
#          tools_index_params[:toolname]

          workflows = workflows.offset(@offset) if @offset
          count = workflows.count
          workflows = workflows.limit(@limit)

          offset = @offset || 0
          response.headers['next_page'] = ga4gh_trs_v2_tools_url(tools_index_params.merge(offset: offset + @limit)) if count > @limit
          response.headers['last_page'] = ga4gh_trs_v2_tools_url(tools_index_params.merge(offset: offset - @limit)) if offset - @limit > 0
          response.headers['current_offset'] = @offset if @offset
          response.headers['current_limit'] = @limit
          response.headers['self_link'] = request.url

          @tools = workflows.map { |workflow| Ga4gh::Trs::V2::Tool.new(workflow) }
        end

        def tools_index_params
          params.permit(%i[id alias toolClass descriptorType registry organization name toolname description author checker offset limit])
        end
      end
    end
  end
end
