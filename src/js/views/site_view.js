
var SiteView = window.SiteView = window.ReviewBaseView.extend({

    get_store: function() {
        return Site_Column_Store;
    },

    render_root: function(model)
    {
        $("#site_id", this.$el).text(model.site.local_db_id);
        this.set_review_value($("#site_name", this.$el), model.site.site_name, model.site.public_site_name);
        this.set_review_value($("#site_description", this.$el),  model.site.site_description, model.site.public_site_description);
        this.set_review_value($("#national_site_identifier", this.$el),  model.site.national_site_identifier, model.site.public_national_site_identifier);
        this.set_review_value($("#preservation_status_or_threat", this.$el),  model.site.preservation_status_or_threat, model.site.public_preservation_status_or_threat);
        this.set_review_value($("#latitude_dd", this.$el),  model.site.latitude_dd, model.site.public_latitude_dd);
        this.set_review_value($("#longitude_dd", this.$el),  model.site.longitude_dd, model.site.public_longitude_dd);
        this.set_review_value($("#altitude", this.$el),  model.site.altitude, model.site.public_altitude);
        this.set_review_value($("#location_accuracy", this.$el),  model.site.site_location_accuracy, model.site.public_site_location_accuracy);
        return this;
    }

});

var Site_Column_Store = window.Site_Column_Store = {

    data_type: "site",

    data_keys: [ "projects", "locations", "references", "natgridrefs", "images" ],

    columns: utils.toArray({
        projects: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Name", column_field: "project_name", public_column_field: "public_project_name" },
            { column_name: "Abbrev", column_field: "project_abbrev", public_column_field: "public_project_abbrev" },
            { column_name: "Type", column_field: "project_type", public_column_field: "public_project_type" },
            { column_name: "Description", column_field: "description", public_column_field: "public_description" }
        ],
        locations: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Name", column_field: "location_name", public_column_field: "public_location_name" },
            { column_name: "Type", column_field: "location_type", public_column_field: "public_location_type" },
            { column_name: "Lat.dd", column_field: "default_lat_dd" },
            { column_name: "Long.dd", column_field: "default_long_dd" },
            { column_name: "Updated", column_field: "date_updated" /*, fn_render: function(d) { return d; } */ }
        ],
        references: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Reference", column_field: "reference", public_column_field: "public_reference" }
        ],
        natgridrefs: [
            { column_name: "Id", column_field: "local_db_id" },
            { column_name: "Method", column_field: "method_name", public_column_field: "public_method_name" },
            { column_name: "Nat.Grid.Ref", column_field: "natgridref", public_column_field: "public_natgridref" }
        ],
        images: [
        ]
    })
};

export { SiteView, Site_Column_Store };