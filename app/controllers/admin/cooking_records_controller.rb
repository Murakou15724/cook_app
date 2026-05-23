module Admin
  class CookingRecordsController < BaseController
    before_action :set_cooking_record, only: [:destroy]

    def index
      @cooking_records = CookingRecord.includes(:user).newest_first
    end

    def destroy
      redirect_to admin_cooking_records_path, notice: "管理者過去料理削除は後続issueで実装します"
    end

    private

    def set_cooking_record
      @cooking_record = CookingRecord.find(params[:id])
    end
  end
end
