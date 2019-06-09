

var SampleView = window.SampleView = window.ReviewBaseView.extend({

    get_store: function() {
        return Sample_Column_Store;
    },

    render_root: function(model)
    {
        $("#sample_id", this.$el).text(model.sample.local_db_id);
        this.set_review_value($("#sample_name", this.$el), model.sample.sample_name, model.sample.public_sample_name);
        this.set_review_value($("#sample_name_type", this.$el), model.sample.sample_name_type, model.sample.public_sample_name_type);
        this.set_review_value($("#date_sampled", this.$el), model.sample.date_sampled, model.sample.public_date_sampled);
        this.set_review_value($("#type_name", this.$el), model.sample.type_name, model.sample.public_type_name);
        return this;
    }

});

var Sample_Column_Store = window.Sample_Column_Store = {

    data_type: "sample",

    data_keys: ["locations", "alternative_names", "features", "notes", "dimensions", "descriptions", "horizons", "colours", "images" ],

    columns: utils.toArray({

        alternative_names: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Alt. ref", column_field: "alt_ref", public_column_field: "public_alt_ref" },
            { column_name: "Type", column_field: "alt_ref_type", public_column_field: "public_alt_ref_type" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        features: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Feature", column_field: "feature_name", public_column_field: "public_feature_name" },
            { column_name: "Description", column_field: "feature_description", public_column_field: "public_feature_description" },
            { column_name: "Type", column_field: "feature_type_name", public_column_field: "public_feature_type_name" }
        ],
        notes: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Note Type", column_field: "note_type", public_column_field: "public_note_type" },
            { column_name: "Note", column_field: "note", public_column_field: "public_note" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        dimensions: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Value", column_field: "dimension_value", public_column_field: "public_dimension_value" },
            { column_name: "Dimension", column_field: "dimension_name", public_column_field: "public_dimension_name" },
            { column_name: "Method", column_field: "method_name", public_column_field: "public_method_name" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        descriptions: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Group desc.", column_field: "group_description", public_column_field: "public_group_description" },
            { column_name: "Type name", column_field: "type_name", public_column_field: "public_type_name" },
            { column_name: "Type desc.", column_field: "type_description", public_column_field: "public_type_description" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        horizons: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Horizon", column_field: "horizon_name", public_column_field: "public_horizon_name" },
            { column_name: "Description", column_field: "description", public_column_field: "public_description" },
            { column_name: "Method", column_field: "method_name", public_column_field: "public_method_name" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        colours: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Colour", column_field: "colour_name", public_column_field: "public_colour_name" },
            { column_name: "rgb", column_field: "rgb", public_column_field: "public_rgb" },
            { column_name: "Method", column_field: "method_name", public_column_field: "public_method_name" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        images: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Description", column_field: "description", public_column_field: "public_description" },
            { column_name: "Name", column_field: "image_name", public_column_field: "public_image_name" },
            { column_name: "Type", column_field: "image_type", public_column_field: "public_image_type" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        locations: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Location", column_field: "location", public_column_field: "public_location" },
            { column_name: "Type", column_field: "location_type", public_column_field: "public_location_type" },
            { column_name: "Description", column_field: "description", public_column_field: "public_description" },
            { column_name: "Updated", column_field: "date_updated" }
        ],
        positions: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Position", column_field: "sample_position", public_column_field: "public_sample_position" },
            { column_name: "Accuracy", column_field: "position_accuracy", public_column_field: "public_position_accuracy" },
            { column_name: "Method", column_field: "method_name", public_column_field: "public_method_name" }
        ],
        dendro_dates: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Sample name", column_field: "sample_name", public_column_field: "public_sample_name" },
            { column_name: "Type", column_field: "dating_type", public_column_field: "public_dating_type" },
            { column_name: "Season", column_field: "season_type", public_column_field: "public_season_type" },
            { column_name: "Dating", column_field: "date", public_column_field: "public_date" },
            { column_name: "Error: years -", column_field: "error_years_minus", public_column_field: "public_error_years_minus" },
            { column_name: "Error: years +", column_field: "error_years_plus", public_column_field: "public_error_years_plus" }
        ],
        dendro_date_notes: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Note", column_field: "note", public_column_field: "public_note" },
            { column_name: "Updated", column_field: "date_updated" }
        ]
    })
};

export { SampleView, Sample_Column_Store };
