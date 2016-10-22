var path              = require('path');
var webpack           = require('webpack');

module.exports = {
  devtool: 'cheap-module-source-map',
  entry: [
    './index.coffee'
  ],
  output: {
    libraryTarget: 'commonjs2',
    library: 'Inquisitor',
    path: path.join(__dirname, 'dist'),
    filename: 'bundle.js'
  },
  module: {
    loaders: [
      {
        test: /\.coffee$/, loader: 'coffee', include: /src/
      }
    ]
  },
  plugins: [
    new webpack.IgnorePlugin(/^(buffertools)$/), // unwanted "deeper" dependency
    new webpack.NoErrorsPlugin(),
    new webpack.optimize.OccurenceOrderPlugin(),
    new webpack.DefinePlugin({
      'process.env': {
        'NODE_ENV': JSON.stringify('production')
      }
    }),
    new webpack.optimize.UglifyJsPlugin({
      compressor: {
        screw_ie8: true,
        warnings: false
      }
    })
  ]
};
