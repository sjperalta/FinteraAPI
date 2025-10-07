# frozen_string_literal: true

# app/services/projects/create_project_service.rb

module Projects
  # Service to create a project along with its associated lots
  class CreateProjectService
    def initialize(project_params)
      @project_params = project_params
      @lot_count = project_params[:lot_count].to_i
    end

    def call
      # exclude lot_count from project attributes
      @project_params = @project_params.except(:lot_count)

      # Create the project
      project = Project.new(@project_params)

      if project.save
        create_lots(project)
        { success: true, project: }
      else
        { success: false, errors: project.errors.full_messages }
      end
    end

    private

    def create_lots(project)
      (1..@lot_count).each do |i|
        project.lots.create(
          name: "Lote #{i}",
          address: 'Etapa 1',
          length: rand(10..30),
          width: rand(10..30)
        )
      end
    end
  end
end
