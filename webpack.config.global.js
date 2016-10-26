var path              = require('path');
var webpack           = require('webpack');

module.exports = {
  entry: [
    './index.coffee'
  ],
  output: {
    library: 'MeshbluHttp',
    path: path.join(__dirname, 'deploy', 'inquisitor', 'latest'),
    filename: 'inquisitor.bundle.js'
  },
  module: {
    loaders: [
      {
        test: /\.coffee$/, loader: 'coffee-loader', include: [/src/, /node_modules/]
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
