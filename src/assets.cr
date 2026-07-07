require "../vendor/asset_pipeline/asset_pipeline"

# One import map for the whole app, built with asset_pipeline's FrontLoader.
#
# FrontLoader fingerprints each local JS file (SHA-256), copies it from
# js_source_path into js_output_path, and rewrites the import-map entry to
# the fingerprinted URL. The layout calls Assets.import_map_tag to emit the
# <script type="importmap"> tag.
module Assets
  # js_output_path MUST be your static root ("public"), not a subfolder.
  # FrontLoader builds public URLs by replacing js_output_path with "/",
  # so "public/assets" would emit URLs that 404. See the README gotchas.
  FRONT_LOADER = AssetPipeline::FrontLoader.new(
    js_source_path: Path.new("src/app/javascript"),
    js_output_path: Path.new("public")
  )

  import_map = FRONT_LOADER.get_import_map
  import_map.add_import("@hotwired/stimulus", "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/+esm", preload: true)
  import_map.add_import("HelloController", "hello_controller.js")

  @@tag : String?

  # Render once per process and cache. render_import_map_tag mutates state
  # (it appends a modulepreload <link> on every call), so calling it on each
  # request would duplicate the preload tags — and re-hash your JS files.
  def self.import_map_tag : String
    @@tag ||= FRONT_LOADER.render_import_map_tag
  end
end
