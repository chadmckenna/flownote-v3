class FoldersController < ApplicationController
  include ShellLoader

  # See NotesController: force the full layout so editor_main / folder_context render on
  # Turbo-Frame navigations instead of turbo-rails' minimal frame layout.
  layout "application", only: %i[ index show ]

  before_action :set_folder, only: %i[ show edit update destroy ]
  before_action :require_non_root_folder, only: %i[ edit update destroy ]
  before_action :load_shell, only: %i[ index show ]

  def index
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    redirect_to root_path and return if @folder.root?

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @folder = Current.user.folders.build(parent_id: params[:parent_id] || Current.user.root_folder.id)
  end

  def edit
  end

  def create
    @folder = Current.user.folders.build(folder_params)

    if @folder.save
      redirect_to(helpers.folder_or_root_path(@folder.parent), notice: "Folder was successfully created.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @folder.update(folder_params)
      redirect_to @folder, notice: "Folder was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @folder.destroy
      redirect_to(helpers.folder_or_root_path(@folder.parent), notice: "Folder was successfully deleted.", status: :see_other)
    else
      redirect_to @folder, alert: "Folder cannot be deleted because it is not empty."
    end
  end

  private
    def set_folder
      @folder = Current.user.folders.find(params.expect(:id))
    end

    def folder_params
      params.expect(folder: [ :name, :parent_id ])
    end

    def require_non_root_folder
      head :not_found if @folder.root?
    end
end
