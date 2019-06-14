
const path = require('path');
const webpack = require('webpack');
const HtmlPlugin = require("html-webpack-plugin");

//const copyPlugin = require('copy-webpack-plugin');
//const target = "dev";

//const PORT = 8060;
const PROXY_TARGET_API = null; // "http://localhost:88/"

const resolve = directory => path.resolve(__dirname, directory);

var devServerConfig = null;

if (PROXY_TARGET_API !== null) {
    devServerConfig = {

        contentBase: resolve('public'),
        hot: true,
        port: 8080,
        allowedHosts: ['localhost'],
        //publicPath: resolve('public'),
        proxy: {
            '/api': {
                target: "http://localhost:88/",
                secure: false
            }
        }
    }
} else {
    devServerConfig = {
        publicPath: path.join('/public/')
    };
}

module.exports = {
    entry: path.join(__dirname, 'src/js/main.js'),
    output: {
        filename: 'bundle.js',
        path: path.resolve(__dirname, 'public')
    },
    module: {
        rules: [
            {
                enforce: "pre",
                test: /\.js$/,
                exclude: /node_modules/,
                loader: "eslint-loader",
            },
            {
                test: /\.js$/,
                include: [ path.join(__dirname, 'src') ],
                exclude: /(node_modules|bower_components)/,
                use: {
                    loader: 'babel-loader',
                    options: {
                        presets: ['@babel/preset-env']
                    }
                }
            },
            {
                test: /\.css$/,
                use: ['style-loader', 'css-loader']
            },
            // {
            //     test : /\.(png|gif|jpg|jpeg)$/,
            //     loader: "file-loader"
            // },
            {
                test: /\.(png|gif|jp(e*)g|svg)$/,
                use: [{
                    loader: 'url-loader',
                    options: { limit: 100000, name: 'images/[hash]-[name].[ext]' }
                }]
            },
            {
                test: /\.html$/,
                use: [{
                    loader: 'html-loader',
                    options: {
                        ignoreCustomFragments: [/\{\{.*?}}/],
                        root: path.resolve(__dirname, 'images'),
                        attrs: ['img:src' ]
                    }
                }]
            }
        ]
    },
    plugins: [
        new webpack.LoaderOptionsPlugin({ options: {} }),
        new HtmlPlugin({
            template: "./src/index-template.html",
            inject: "body"
        }),
        new webpack.ProvidePlugin({
            $: "jquery",
            jQuery: "jquery",
            'window.jQuery': 'jquery',
            'window.$': 'jquery',
            _: "underscore",
            Backbone : "backbone",
        }),
        // new copyPlugin([
        //     {
        //         from: __dirname + '/src/api',
        //         to: __dirname + '/public/api',
        //         force: true,
        //     },
        // ]),
        // ,
        // new CopyWebpackPlugin([
        //     {
        //         from: 'conf/' + target,
        //         to: 'zip/conf',
        //         toType: 'dir',
        //         force: true
        //     }
        // ])
    ],
    resolve: {
        extensions: [ '.json', '.js', '.jsx', '.css' ],
        modules: [
            path.resolve('./node_modules'),
        ],
        alias: {
            ImageFiles: path.resolve(__dirname, 'src/images/'),
            CssFiles: path.resolve(__dirname, 'src/css/'),
            TemplateFiles: path.resolve(__dirname, 'src/templates/'),
            'jquery-ui': 'jquery-ui-dist/jquery-ui.js'
        }
    },
    devtool: 'source-map',
    devServer: devServerConfig
};


