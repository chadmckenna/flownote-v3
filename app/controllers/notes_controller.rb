class NotesController < ApplicationController
  include ShellLoader

  before_action :set_folder, only: %i[ show new edit create update destroy ]
  before_action :set_note, only: %i[ show edit update destroy ]
  before_action :load_shell, only: %i[ show edit ]

  def show
  end

  def new
    @note = @folder.notes.build
    @note.user = Current.user
  end

  def edit
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
      redirect_to edit_folder_note_path(@note.folder, @note), notice: "Note `#{@note.title}` was successfully updated."
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
