# app/services/projects/create_project_service.rb

module Projects
  class CreateProjectService
    def initialize(project_params)
      @project_params = project_params
      @lot_count = project_params[:lot_count].to_i
    end

    def call
      project = Project.new(@project_params.except(:lot_count))

      if project.save
        create_lots(project)
        { success: true, project: project }
      else
        { success: false, errors: project.errors.full_messages }
      end
    end

    private

    def create_lots(project)
      (1..@lot_count).each do |i|
        project.lots.create(
          name: "Lote #{i}",
          length: rand(10..30),
          width: rand(10..30)
        )
      end
    end
  end
end
