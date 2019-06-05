import 'jquery-ui';

var SubmissionNavigationView = window.SubmissionNavigationView = Backbone.View.extend({

    initialize: function (options) {

        this.options = options || {};

        this.template = TemplateStore.get("template_SubmissionNavigationView");

        this.submission_id = this.options.submission_id;
        this.submission_metadata_model = this.options.submission_metadata_model;

        this.reports = this.options.reports;

        this.sitesView = new SubmissionSitesNavigationView( { submission_metadata_model: this.submission_metadata_model });
        this.reportsView = new SubmissionReportsNavigationView({ submission_id: this.submission_id, reports: this.reports });
        this.tablesView = new SubmissionTablesNavigationView({ submission_id: this.submission_id, xml_tables_list: this.options.xml_tables_list });

        this.listenTo(this.submission_metadata_model, 'reset', this.renderSites);
        this.listenTo(this.submission_metadata_model, 'change', this.renderSites);
        this.listenTo(this.reports, 'reset', this.renderReports);
        this.listenTo(this, 'render:complete', this.assignToggler);
        this.listenTo(this.tablesView, 'render:complete', this.renderCompleteNotifier);

        $(".left.pane").resizable({ handles: "e, w" });

    },

    events: {
        'render:complete': 'renderComplete'
    },

    render: function () {

        this.renderCounter = 3;

        $(this.el).html(this.template());

        $('#container_SubmissionTablesNavigationView', this.$el).html(this.tablesView.render().el);

        return this;

    },

    renderSites: function () {

        var container = $('#container_SubmissionSitesNavigationView', this.$el);

        container.html(this.sitesView.render().el);
        container.children().children().unwrap(); // Remove surrounding div that underscore adds to inserted fragment

        this.renderCompleteNotifier();

        return this;

    },

    renderReports: function () {

        var container = $('#container_SubmissionReportsNavigationView', this.$el);
        container.html(this.reportsView.render().el);
        container.children().children().unwrap();

        this.renderCompleteNotifier();

        return this;

    },

    renderCompleteNotifier: function()
    {
        this.renderCounter--;
        if (this.renderCounter <= 0) {
            var self = this;
            $("a.tree-link", this.$el).click(
                function (e) { // eslint-disable-line no-unused-vars
                    $("a.tree-link-selected", self.$el).removeClass("tree-link-selected");
                    $(this).addClass("tree-link-selected");
                }
            );
            this.trigger("render:complete");
        }
    },

    assignToggler: function()
    {
        TreeNodeHelper.assignToggler(this.$el);
    },

    renderSiteStatus: function(rejects)
    {
        try {
            $("span[site_id]", this.$el).each(
                function () {
                    $(this).toggleClass("rejected-site", rejects.contains_site_id(parseInt($(this).attr("site_id"))));
                }
            );
        } catch (ex) {
            console.log(ex.message || ex);
        }
    }

});

var SubmissionSitesNavigationView = window.SubmissionSitesNavigationView = Backbone.View.extend({

    initialize: function (options) {
        this.options = options || {};

        this.rootTemplate = TemplateStore.get("template_SiteRootView");
        this.nodeTemplate = TemplateStore.get("template_SiteNodeView");
        this.sampleGroupNodeTemplate = TemplateStore.get("template_SampleGroupNodeView");
        this.sampleNodeTemplate = TemplateStore.get("template_SampleNodeView");
        this.datasetNodeTemplate = TemplateStore.get("template_DatasetNodeView");

        this.submission_metadata_model = this.options.submission_metadata_model;

    },

    render: function () {

        var metadata = this.submission_metadata_model.toJSON();
        var sites = metadata.sites;

        var $sites = [];

        for (var i = 0; i < sites.length; i++) {

            var site = sites[i];
            var $site = $(this.nodeTemplate({ site: site }));
            $sites.push($site);

            if (site.sample_groups.length == 0) {
                continue;
            }

            var $sample_group_placeholder = $("#site_" + site.site_id.toString() + "_sample_groups_placeholder", $site);
            var $sample_groups = [];
            for (var j = 0; j < site.sample_groups.length; j++) {

                var sample_group = site.sample_groups[j];
                var $sample_group = $(this.sampleGroupNodeTemplate({ sample_group: sample_group }));
                $sample_groups.push($sample_group);

                var $samples = [];
                for (var k = 0;k < sample_group.samples.length; k++) {
                    var sample = sample_group.samples[k];
                    var $sample = $(this.sampleNodeTemplate({ sample: sample }));
                    $samples.push($sample);
                }
                var $sample_placeholder = $("#sample_group_" + sample_group.sample_group_id.toString() + "_placeholder", $sample_group);
                $sample_placeholder.append($samples);

                var $datasets = [];
                for (var d = 0;d < sample_group.datasets.length; d++) {
                    var dataset = sample_group.datasets[d];
                    var $dataset = $(this.datasetNodeTemplate({ submission_id: site.submission_id, site_id: site.site_id, dataset: dataset }));
                    $datasets.push($dataset);
                }

                var $dataset_placeholder = $("#sample_group_" + sample_group.sample_group_id.toString() + "_datasets_placeholder", $sample_group);
                $dataset_placeholder.append($datasets);

            }
            $sample_group_placeholder.append($sample_groups);
        }

        $(this.el).html(this.rootTemplate({ site_count: sites.length}));

        var $site_placeholder = $("#template_site_list_placeholder", this.$el);
        $site_placeholder.append($sites);

        return this;
    }

});

var SubmissionReportsNavigationView =  window.SubmissionReportsNavigationView = Backbone.View.extend({

    initialize: function (options) {
        this.options = options || {};
        this.rootTemplate = TemplateStore.get("template_SubmissionReportsNavigationView");
        this.nodeTemplate = TemplateStore.get("template_SubmissionReportNavigationNode");
        this.reports = this.options.reports;
        this.submission_id = this.options.submission_id;
    },

    render: function () {

        var reports = this.reports.toJSON();

        $(this.el).html(this.rootTemplate({ report_count: reports.length }));

        var $list = $("#report_list_placeholder", this.$el);

        for (var i = 0; i < reports.length; i++) {
            $list.append(this.nodeTemplate({ submission_id: this.submission_id, report: reports[i] }));
        }
        return this;
    }
});

var SubmissionTablesNavigationView = window.SubmissionTablesNavigationView = Backbone.View.extend({

    initialize: function (options) {
        this.options = options || {};
        this.rootTemplate = TemplateStore.get("template_SubmissionTablesNavigationView");
        this.nodeTemplate = TemplateStore.get("template_SubmissionTablesNavigationNode");
        this.xml_tables_list = this.options.xml_tables_list;
        this.listenTo(this.xml_tables_list, 'reset', this.renderLeafs);
        this.listenTo(this.xml_tables_list, 'change', this.renderLeafs);
    },

    render: function()
    {
        $(this.el).html(this.rootTemplate());
        return this;
    },

    renderLeafs: function()
    {
        var tables = this.xml_tables_list.toJSON();
        var $root = $("#tables_list_placeholder", this.$el);
        $("#xml_table_count", this.$el).html(tables.length.toString());
        for (var i = 0; i < tables.length; i++) {
            $root.append(this.nodeTemplate({ submission_id: this.options.submission_id, item: tables[i] }));
        }
        $('#container_SubmissionTablesNavigationView').children().children().unwrap();
        this.trigger("render:complete");
        return this;
    }
});

var TreeNodeHelper = {

    assignToggler: function(context)
    {
        //$('.collapse').on('shown.bs.collapse, hidden.bs.collapse', function () {
        //    $(this).parent().prev('button').find('span').toggleClass('glyphicon-plus glyphicon-minus');
        //});

        $('.tree li:has(ul)', context).addClass('parent_li').find(' > span').attr('title', 'Collapse this branch');
        $('.tree li.parent_li > span', context).on('click', function (e) {
            var $self = $(this);
            var children = $self.parent('li.parent_li').find(' > ul'); // > li');
            if (children.is(":visible")) {
                children.hide(0); //'fast');
                $self.attr('title', 'Expand this branch').find(' > i').addClass('glyphicon-plus').removeClass('glyphicon-minus');
            } else {
                children.show(0); // ('fast');
                $self.attr('title', 'Collapse this branch').find(' > i').addClass('glyphicon-minus').removeClass('glyphicon-plus');
            }
            e.stopPropagation();
        });
        return this;
    }

};

export { SubmissionNavigationView, SubmissionSitesNavigationView, SubmissionReportsNavigationView, SubmissionTablesNavigationView, TreeNodeHelper };

