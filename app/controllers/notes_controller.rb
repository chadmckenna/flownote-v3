class NotesController < ApplicationController
  before_action :set_folder, only: %i[ show new edit create update destroy ]
  before_action :set_note, only: %i[ show edit update destroy ]

  def show
    load_folder_sidebar
  end

  def new
    @note = @folder.notes.build
    @note.user = Current.user
  end

  def edit
    load_folder_sidebar
  end

  def create
    @note = Current.user.notes.build(note_params)

    if @note.save
      redirect_to(@note.folder.root? ? root_path : folder_path(@note.folder), notice: "Note was successfully created.")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Note `#{@note.title}` was successfully updated."
          render turbo_stream: turbo_stream.update("flash-slot", partial: "shared/flashes")
        end
        format.html { redirect_to edit_folder_note_path(@note.folder, @note), notice: "Note was successfully updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    folder = @note.folder
    @note.destroy!
    redirect_to(folder.root? ? root_path : folder_path(folder), notice: "Note was successfully deleted.", status: :see_other)
  end

  def quick_new
    @note = Current.user.notes.build(folder_id: Current.user.root_folder.id)
  end

  def quick_create
    @note = Current.user.notes.build(note_params)

    if @note.save
      redirect_to folder_note_path(@note.folder, @note), notice: "Note was successfully created."
    else
      render :quick_new, status: :unprocessable_entity
    end
  end

  private
    def set_folder
      @folder = Current.user.folders.find(params.expect(:folder_id))
    end

    def set_note
      @note = @folder.notes.find(params.expect(:id))
    end

    def note_params
      params.expect(note: [ :title, :body, :folder_id ])
    end

    def load_folder_sidebar
      @subfolders = @folder.subfolders.order(:name)
      @sibling_notes = @folder.notes.order(updated_at: :desc)
      @ancestors = @folder.ancestors
    end
end
