include AdventistPublishingCenter::Articles
include AdventistPublishingCenter::Factsheets

module API
	module V1
		class Factsheets < Grape::API
			include API::V1::Auth

			post :validate_factsheet_slug do
				id = params[:factsheet][:id]
				url = params[:factsheet][:url]

				is_valid = factsheet_validate_slug_for_url(id ,url) if url.present?
				{ status: true,
					code: 200,
					message: '',
					data: {is_valid: is_valid}
				}
			end

			get :factsheet_detail do
        factsheet_id = params[:factsheet_id]
				factsheet_detail = factsheet_detail(factsheet_id)
				{
					status: true,
					code: 200,
					message: '',
					data: factsheet_detail
				}
      end

			get :glossory_reference_data do
				detail = factsheet_glossory_reference_detail params[:glossary_id], params[:reference_id]
				{
					status: true,
					code: 200,
					message: '',
					data: detail
				}
			end

			get :glossories do
				detail = glossaries
				{
					status: true,
					code: 200,
					message: '',
					data: detail
				}
			end
		end
	end
end
