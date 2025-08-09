Inputs: SeatMap doc id.
Outputs: seatmap.json + SVG slices directory (v1), optional label sprite.
Compression: pre-compress gzip + brotli.
Upload path schema: /seatmaps/{tenant}/{venue}/{version}/..., write back tileset_ref to Mongo.
Targets: typical venue base bundle < ~1.5 MB; lazy-load long tails.
