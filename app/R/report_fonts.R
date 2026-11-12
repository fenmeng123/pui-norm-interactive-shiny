# Linux Cairo uses fontconfig, not systemfonts' in-memory font registry.
# Configure before the first graphics device; no OS font install is needed.
configure_pui_fonts <- function(font_dir = "fonts") {
  font_dir <- normalizePath(font_dir, winslash = "/", mustWork = TRUE)
  font_file <- file.path(font_dir, "NotoSansCJKsc-Regular.otf")
  if (!file.exists(font_file)) stop("The bundled report font is missing.")
  if (identical(Sys.info()[["sysname"]], "Linux")) {
    config <- tempfile("pui-fontconfig-", fileext = ".conf")
    cache <- tempfile("pui-font-cache-")
    dir.create(cache)
    doc <- xml2::xml_new_root("fontconfig")
    xml2::xml_add_child(doc, "include", "/etc/fonts/fonts.conf", ignore_missing = "yes")
    xml2::xml_add_child(doc, "dir", font_dir)
    xml2::xml_add_child(doc, "cachedir", cache)
    xml2::write_xml(doc, config)
    Sys.setenv(FONTCONFIG_FILE = config)
  }
  systemfonts::add_fonts(font_file)
  invisible(font_file)
}

pui_report_family <- function() {
  if (identical(Sys.info()[["sysname"]], "Linux")) return("Noto Sans CJK SC")
  available <- unique(systemfonts::system_fonts()$family)
  preferred <- c("Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Zen Hei", "SimHei", "STHeiti")
  found <- preferred[preferred %in% available]
  if (!length(found)) stop("A CJK-capable system font is required on this platform.")
  found[1]
}
