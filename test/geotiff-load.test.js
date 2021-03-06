var mapnik = require('../');
var assert = require('assert');
var path = require('path');
var fs = require('fs');
var existsSync = require('fs').existsSync || require('path').existsSync;

describe('reading GeoTIFF in threads', function() {
    // puts unnatural, odd, and intentionally racey load on opening geotiff
    it('should be able to open geotiff various ways without crashing', function(done) {
        mapnik.register_datasource(path.join(mapnik.settings.paths.input_plugins,'gdal.input'));
        var vtile = new mapnik.VectorTile(0, 0, 0);
        var map = new mapnik.Map(256, 256);
        map.load('./test/data/vector_tile/raster_layer.xml',{},function(err,map) { if (err) throw err; });
        map.render(vtile,{},function(err,vtile) {
            if (err) throw err;
        });
        var map2 = new mapnik.Map(256, 256);
        map2.load('./test/data/vector_tile/raster_layer.xml',{},function(err,map) { if (err) throw err; });
        var map3 = new mapnik.Map(256, 256);
        map3.load('./test/data/vector_tile/raster_layer.xml',{},function(err,map) { if (err) throw err; });
        map3.render(vtile,{},function(err,vtile) {
            if (err) throw err;
            done();
        });
    });
});
