class FoldersController < ApplicationController
  before_action :set_folder, only: %i[ show edit update destroy ]
  before_action :require_non_root_folder, only: %i[ edit update destroy ]

  def index
    @folder = Current.user.root_folder
    @subfolders = @folder.subfolders.order(:name)
    @notes = @folder.notes.order(updated_at: :desc)
  end

  def show
    redirect_to root_path and return if @folder.root?

    @subfolders = @folder.subfolders.order(:name)
    @notes = @folder.notes.order(updated_at: :desc)
    @ancestors = @folder.ancestors
  end

  def new
    @folder = Current.user.folders.build(parent_id: params[:parent_id] || Current.user.root_folder.id)
  end

  def edit
  end

  def create
    @folder = Current.user.folders.build(folder_params)

    if @folder.save
      redirect_to(@folder.parent.root? ? root_path : @folder.parent, notice: "Folder was successfully created.")
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
      redirect_to(@folder.parent.root? ? root_path : @folder.parent, notice: "Folder was successfully deleted.", status: :see_other)
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
