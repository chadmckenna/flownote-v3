class NotesController < ApplicationController
  before_action :set_folder
  before_action :set_note, only: %i[ show edit update destroy ]

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
      redirect_to folder_note_path(@note.folder, @note), notice: "Note was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @note.update(note_params)
      redirect_to folder_note_path(@note.folder, @note), notice: "Note was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    folder = @note.folder
    @note.destroy!
    redirect_to(folder.root? ? root_path : folder_path(folder), notice: "Note was successfully deleted.", status: :see_other)
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
