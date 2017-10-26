window.Table_Template_Store = {

    template: function(data_type, data_key, columns) {
        
        return {
            
            data_key: data_key,
            target: "#" + data_type + "_" + data_key + "_table_container",
            container: "#" + data_type + "-" + data_key + "-container", /* surrounding tab i.e. panel */
            
            options: {
                table_id: "" + data_type + "_" + data_key + "_table",
                row_id_prefix: "" + data_type + "_" + data_key + "_table_row_id_",
                indicator_id_prefix: "" + data_type + "_" + data_key + "_table_indicator_row_id_",
                entity_type_id: 0,
                row_class: "",
                columns: columns,
                data: null,
                rejects: null
            },
            
            indicator_option: {
                target: "#" + data_type + "_" + data_key + "_generic_indicator_container",
                local_db_id: 0,
                entity_type_id: 0,
                indicator_id_prefix: "generic_" + data_key + "_indicator_id_"
            }
        };
    },
    
    get_table_options: function(store) {
        var _options = new Array();
        for (var data_key in store.columns) {
            _options.push(this.template(store.data_type, data_key, store.columns[data_key]));
        }
        return _options;
    }
    
};

window.ReviewTableView = window.ReviewView.extend({

    initialize: function () {


        this.template = TemplateStore.get("template_ReviewTable");
        this.row_template = TemplateStore.get("template_ReviewTableRow");
        
        this.options = $.extend({}, {
            data: [],
            columns: [],
            entity_type_id: 0,
            row_id_prefix: "",
            indicator_id_prefix: this.options.indicator_id_prefix || (this.options.row_id_prefix + "_indicator_"),
            row_class: ""
        }, this.options);
        
    },

    render: function () {

        this.$el.html(this.template({
            table_id: this.options.table_id,
            //columns: this.options.columns,
            classname: "display table table-condensed sead-smaller-font-size"
        }));
        
        this.render_data();

        return this;
    },
    
    render_columns: function(columns)
    {
        var $table = $("#" + this.options.table_id, this.$el);
        var $header = $("thead", $table);
        var $tr = $("<tr/>");
        $tr.append("<th/>");
        _.each(columns, function(column) {
            $tr.append($("<th/>", 
                $.extend({
                    text: column.column_name
                }, column.column_tooltip ? {
                    title: column.column_tooltip
                } : {}, column.class ? {
                    class: column.class
                } : {} )
            ));
        });
        $header.append($tr);
    },
    
    render_data: function()
    {
        var data = this.options.data.data ?  this.options.data.data :  this.options.data;
        var columns = this.options.data.columns ? this.options.data.columns : this.options.columns;
        
        var $table = $("#" + this.options.table_id, this.$el);
        
        if (columns) {
            this.render_columns(columns);
        }
        
        var $body = $("tbody", $table);
        
        var options = this.options;
        var placeholder = $("<tbody/>");
        var template = this.row_template;
        var entity_type_id = this.getEntityTypeId();
        var rejects = this.options.rejects;
        
        _.each(
                
            data,
    
            function (row) {
                
                var $row_text = $(template( {
                    options : options,
                    columns: columns,
                    row: row
                }));

                if (rejects) {
                    $(".indicator-container", $row_text).html(
                        new RejectCauseIndicatorView({
                            local_db_id: row["local_db_id"],
                            entity_type_id: entity_type_id,
                            indicator_id_prefix: options.indicator_id_prefix,
                            rejects: rejects
                        }
                    ).render().el);
                }

                placeholder.append($row_text);
            }
        );
        $body.empty();
        $body.append(placeholder.children());
    },

    getEntityTypeId: function()
    {
        var options = this.options;
        if (options.entity_type_id === 0 && options.data) {
            options.entity_type_id = utils.getEntityTypeOf(options.data);
        }
        return options.entity_type_id;
    }

});
