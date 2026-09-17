class NotesController < ApplicationController
  include ShellLoader

  before_action :set_folder, only: %i[ show new edit create update destroy ]
  before_action :set_note, only: %i[ show edit update destroy ]
  before_action :load_shell, only: %i[ show edit ]
  # Opening a note in either mode counts as visiting it — the sidebar and search
  # results link to edit, the breadcrumb and note links to show.
  after_action :remember_note, only: %i[ show edit ]

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
    def remember_note
      record_recent_note(@note)
    end

    def set_folder
      @folder = Current.user.folders.find(params.expect(:folder_id))
    end

    # Scoped by owner as well as folder. Note#folder_belongs_to_same_user keeps the
    # two in sync, but reads shouldn't depend on that invariant holding.
    def set_note
      @note = Current.user.notes.find_by!(id: params.expect(:id), folder: @folder)
    end

    def note_params
      params.expect(note: [ :title, :body, :folder_id ])
    end
end
