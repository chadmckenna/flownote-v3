module Api
  module V1
    class FoldersController < BaseController
      before_action -> { doorkeeper_authorize! :write }, only: %i[create destroy]

      def index
        scope = if params[:path].present?
          root = resolve_path!(params[:path])
          if ActiveModel::Type::Boolean.new.cast(params[:recursive])
            descendants_including(root)
          else
            current_user.folders.where(id: [ root.id, *root.subfolders.pluck(:id) ])
          end
        else
          current_user.folders
        end

        render json: scope.order(:parent_id, :name).map { |f| folder_json(f) }
      end

      def show
        folder = current_user.folders.find(params[:id])
        render json: folder_json(folder)
      end

      def create
        folder = current_user.folders.build(folder_params)
        if folder.save
          render json: folder_json(folder), status: :created
        else
          render json: { errors: folder.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        folder = current_user.folders.find(params[:id])
        if folder.destroy
          head :no_content
        else
          render json: { errors: folder.errors }, status: :unprocessable_entity
        end
      end

      private
        def folder_params
          params.expect(folder: [ :name, :parent_id ])
        end

        def folder_json(folder)
          {
            id: folder.id,
            name: folder.name,
            parent_id: folder.parent_id,
            root: folder.root?,
            updated_at: folder.updated_at.iso8601
          }
        end

        def resolve_path!(path)
          folder = current_user.root_folder
          path.split("/").reject(&:blank?).each do |segment|
            folder = folder.subfolders.find_by!(name: segment)
          end
          folder
        end

        def descendants_including(root)
          ids = [ root.id ]
          frontier = [ root.id ]
          until frontier.empty?
            children = current_user.folders.where(parent_id: frontier).pluck(:id)
            ids.concat(children)
            frontier = children
          end
          current_user.folders.where(id: ids)
        end
    end
  end
end
