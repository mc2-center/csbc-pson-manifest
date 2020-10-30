## Prettify a string that will cater to Synapse naming rules, e.g.
## can only contain letters, numbers, spaces, underscores, hypens,
## periods, plus signs, apostrophes, and parentheses.
syn_prettify <- function(name) {
  stringr::str_replace_all(name, c(":" = "-", ";" = "-", "/" = "_"))
}


## Create a "list" of annotations; some of the table schemas require
## a column to be a StringList, e.g. '["a", "b"]' instead of 'a, b'.
create_listed_annots <- function(annots, delim = ",") {
  split_annots <- lapply(stringr::str_split(annots, delim), trimws)[[1]]
  paste0(
    "[\"",
    paste0(split_annots, collapse = "\", \""),
    "\"]"
  )
}


## Create markdown for URL
create_url_markdown <- function(link_text, url, param) {
  paste0("[\"[", link_text, "](", url, param, ")\"]")
}


## Save new entity to Synapse; Folder for dataset manifest, File for others
save_file_to_synapse <- function(synapseclient, name,
                                 parent, annotations) {
  name <- syn_prettify(name)

  # create dummy file to upload to Synapse
  write(name, file = name)
  new_file <- synapseclient$File(
    path = name,
    name = name,
    parent = parent,
    annotations = annotations
  )
  new_file <- syn_store(new_file)

  # remove dummy file
  file.remove(name)

  new_file$id
}
save_folder_to_synapse <- function(synapseclient, name,
                                   parent, annotations) {
  name <- syn_prettify(name)
  new_folder <- synapseclient$Folder(
    name,
    parent = parent,
    annotations = annotations
  )
  new_folder <- syn_store(new_folder)
  new_folder$id
}

## Set annotations for a given entity, depending on manifest type.
publication_annots <- function(manifest) {
  list(
    doi = manifest[["doi"]],
    title = manifest[["publicationTitle"]],
    journal = manifest[["journal"]],
    publicationYear = manifest[["publicationYear"]],
    keywords = manifest[["keywords"]],
    pubMedUrl = manifest[["pubMedUrl"]],
    pubMedLink = manifest[["pubMedUrl"]],
    assay = manifest[["assay"]],
    tissue = manifest[["tissue"]],
    tumorType = manifest[["tumorType"]]
  )
}
dataset_annots <- function(manifest) {
  list(
    fullName = manifest[["datasetName"]],
    displayName = manifest[["datasetId"]]
  )
}
tool_annots <- function(manifest, grants) {
  list(
    displayName = manifest[["tool"]],
    grantId = grants[grants$grantNumber == manifest[["grantNumber"]], ]$grantId, #nolint
    toolType = manifest[["toolType"]]
  )
}

## Create tibble for entry into * - Merged tables.
publication_row <- function(syn_id, manifest, grants, publications, datasets) {
  tibble(
    publicationId = syn_id,
    doi = manifest[["doi"]],
    journal = manifest[["journal"]],
    pubMedId = manifest[["pubMedId"]],
    pubMedUrl = manifest[["pubMedUrl"]],
    pubMedLink = paste0("[", manifest[["publicationTitle"]], "](", manifest[["pubMedUrl"]], ")"), #nolint
    publicationTitle = manifest[["publicationTitle"]],
    publicationYear = manifest[["publicationYear"]],
    keywords = manifest[["keywords"]],
    authors = manifest[["authors"]],
    assay = create_listed_annots(manifest[["assay"]]),
    tumorType = create_listed_annots(manifest[["tumorType"]]),
    tissue = create_listed_annots(manifest[["tissue"]]),
    themeId = grants[grants$grantNumber == manifest[["grantNumber"]], ]$themeId, #nolint
    theme = grants[grants$grantNumber == manifest[["grantNumber"]], ]$theme,
    consortiumId = grants[grants$grantNumber == manifest[["grantNumber"]], ]$consortiumId, #nolint
    consortium = manifest[["consortium"]],
    grantId = create_listed_annots(manifest[["grantId"]]),
    grantName = create_listed_annots(grants[grants$grantNumber == manifest[["grantNumber"]], ]$grantName), #nolint
    grantNumber = create_listed_annots(manifest[["grantNumber"]]),
    grantInstitution = create_listed_annots(grants[grants$grantNumber == manifest[["grantNumber"]], ]$grantInstitution), #nolint
    datasetId = "",
    dataset = manifest[["dataset"]]
  )
}
dataset_row <- function(syn_id, manifest, grants, publications) {
  tibble(
    datasetId = syn_id,
    datasetName = manifest[["datasetName"]],
    datasetAlias = manifest[["datasetId"]],
    description = manifest[["description"]],
    overallDesign = manifest[["overallDesign"]],
    assay = create_listed_annots(manifest[["assay"]]),
    species = create_listed_annots(manifest[["species"]]),
    tumorType = create_listed_annots(manifest[["tumorType"]]),
    themeId = ,
    theme = ,
    consortiumId = ,
    consortium = ,
    grantId = create_listed_annots(),
    grantName = create_listed_annots(),
    grantNumber = manifest[["grantNumber"]],
    publicationId = ,
    publicationTitle = ,
    publication = ,
    externalLink =
  )
}
tool_row <- function(syn_id, manifest, grants, publications) {
  tibble(
    toolId = syn_id,
    toolName = manifest[["toolName"]],
    description = manifest[["description"]],
    homepageUrl = manifest[["homepageUrl"]],
    toolType = manifest[["toolType"]],
    softwareLanguage = create_listed_annots(manifest[["softwareLanguage"]]),
    inputDataType = create_listed_annots(manifest[["inputDataType"]]),
    outputDataType = create_listed_annots(manifest[["outputDataType"]]),
    themeId = grants[grants$grantNumber == manifest[["grantNumber"]], ]$themeId, #nolint
    theme = grants[grants$grantNumber == manifest[["grantNumber"]], ]$theme, #nolint
    consortiumId = grants[grants$grantNumber == manifest[["grantNumber"]], ]$consortiumId, #nolint 
    consortium = grants[grants$grantNumber == manifest[["grantNumber"]], ]$consortium, #nolint
    grantId = create_listed_annots(grants[grants$grantNumber == manifest[["grantNumber"]], ]$grantId), #nolint
    grantName = create_listed_annots(grants[grants$grantNumber == manifest[["grantNumber"]], ]$grantName), #nolint
    grantNumber = create_listed_annots(manifest[["grantNumber"]]),
    publicationId = ifelse(
      manifest[["publicationTitle"]] %in% publications$publicationTitle,
      publications[publications$publicationTitle == manifest[["publicationTitle"]], ]$publicationId, #nolint 
      "[]"
    ),
    publicationTitle = create_listed_annots(manifest[["publicationTitle"]]),
    publication = ifelse(
      manifest[["publicationTitle"]] %in% publications$publicationTitle, 
      create_url_markdown(
        manifest[["publicationTitle"]], 
        "https://www.ncbi.nlm.nih.gov/pubmed/?term=", 
        publications[publications$publicationTitle == manifest[["publicationTitle"]], ]$pubMedId #nolint
      ),
      "[]"
    )
  )
}
