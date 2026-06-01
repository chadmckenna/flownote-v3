class NotesController < ApplicationController
  include ShellLoader

  # editor_main / folder_context turbo-frames live in the application layout, so frame
  # navigations here must render the full layout. Otherwise turbo-rails substitutes its
  # minimal "turbo_rails/frame" layout, which omits those frames ("Content missing").
  layout "application", only: %i[ show edit ]

  before_action :set_folder, only: %i[ show new edit create update destroy ]
  before_action :set_note, only: %i[ show edit update destroy ]
  before_action :load_shell, only: %i[ show edit ]

  def show
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @note = @folder.notes.build
    @note.user = Current.user
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @note = Current.user.notes.build(note_params)

    if @note.save
      redirect_to edit_folder_note_path(@note.folder, @note), notice: "Note was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Note `#{@note.title}` was successfully updated."
          render turbo_stream: turbo_stream.update("flash-slot", partial: "layouts/shared/flashes")
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
    redirect_to(helpers.folder_or_root_path(folder), notice: "Note was successfully deleted.", status: :see_other)
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
end
