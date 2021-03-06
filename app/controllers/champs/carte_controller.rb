class Champs::CarteController < ApplicationController
  before_action :authenticate_logged_user!

  EMPTY_GEO_JSON = '[]'
  ERROR_GEO_JSON = ''

  def show
    @selector = ".carte-#{params[:position]}"

    if params[:dossier].key?(:champs_attributes)
      coordinates = params[:dossier][:champs_attributes][params[:position]][:value]
    else
      coordinates = params[:dossier][:champs_private_attributes][params[:position]][:value]
    end

    if params[:champ_id].present?
      @champ = Champ
        .joins(:dossier)
        .where(dossiers: { user_id: logged_user_ids })
        .find(params[:champ_id])
    else
      @champ = Champs::CarteChamp.new(type_de_champ: TypeDeChamp.new(
        type_champ: TypeDeChamp.type_champs.fetch(:carte),
        options: {
          quartiers_prioritaires: true,
          cadastres: true
        }
      ))
    end

    geo_areas = []

    if coordinates == EMPTY_GEO_JSON
      @champ.value = nil
      @champ.geo_areas = []
    elsif coordinates == ERROR_GEO_JSON
      @error = true
      @champ.value = nil
      @champ.geo_areas = []
    else
      coordinates = JSON.parse(coordinates)

      if @champ.cadastres?
        cadastres = ApiCartoService.generate_cadastre(coordinates)
        geo_areas += cadastres.map do |cadastre|
          cadastre[:source] = GeoArea.sources.fetch(:cadastre)
          cadastre
        end
      end

      if @champ.quartiers_prioritaires?
        quartiers_prioritaires = ApiCartoService.generate_qp(coordinates)
        geo_areas += quartiers_prioritaires.map do |qp|
          qp[:source] = GeoArea.sources.fetch(:quartier_prioritaire)
          qp
        end
      end

      if @champ.parcelles_agricoles?
        parcelles_agricoles = ApiCartoService.generate_rpg(coordinates)
        geo_areas += parcelles_agricoles.map do |parcelle_agricole|
          parcelle_agricole[:source] = GeoArea.sources.fetch(:parcelle_agricole)
          parcelle_agricole
        end
      end

      @champ.geo_areas = geo_areas.map do |geo_area|
        GeoArea.new(geo_area)
      end

      @champ.value = GeojsonService.to_json_polygon_for_selection_utilisateur(coordinates)
    end

    if @champ.persisted?
      @champ.save
    end
  end
end
