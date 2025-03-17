using HTTP, Gumbo, Cascadia

function main()
  html = try
    get_downloads_page()
  catch e
    throw(ErrorException("""Failed to successfully signin and fetch the downloads page from epsg.org. \n
      If the login process seem to have changed and as a shortcut to fixing these scripts right now, \
      You can signin manually from a browser, save the html page of https://epsg.org/download-dataset.html \
      to a file, and run get_dataset_zip("path/to/downloads.html").
      """))
  end
  
  get_dataset_zip(html)
end

function get_downloads_page()::HTMLDocument
  @info "Step 1: fetch the espg-download.html page"
  # Clear cookies to make sure we are starting the process from scratch 
  HTTP.CookieRequest.COOKIEJAR.entries |> empty!
  include("./login.jl")
  
  resp = HTTP.get("https://epsg.org/download-dataset.html")
  html = parsehtml(String(resp.body))
  @assert html.root.children[1].children[1].children[1].text == "EPSG Dataset Download"
  return html
end


function get_dataset_zip(html::HTMLDocument)  
  @info "Step 2: find the download link for the WKT zip"
  # link_selector = Selector("""a[title="EPSG-v12_004-WKT.Zip"]""")
  link_selector = Selector("""a[title*="WKT"]""")
  links = eachmatch(link_selector, html.root)
  @assert length(links) == 1 "Expected to find one dataset download link, found $(length(links))"
  download_url = links[1].attributes["href"]
  filename = links[1].attributes["title"]
  # extract version from a title such as "EPSG-v12_004-WKT.Zip"
  match_version = match(r"(v\d+_\d+)", filename)
  @assert !isnothing(match_version) "Could not extract version from filename: $filename"
  @assert length(match_version.captures) == 1 
  version = match_version.captures[1]
  
  @info "Step 3: download the zip file"
  zip_resp = HTTP.request("GET", download_url)
  @assert zip_resp.status == 200 "Failed to download WKT zip file, status code: $(zip_resp.status)"
  @assert lowercase(HTTP.header(zip_resp, "Content-Type")) == "application/zip"
  write(filename, zip_resp.body)
  @info "Downloaded WKT zip file to $(joinpath(pwd(), filename))"
  
  @info "Step 4: commit and push the file"
  # repo = LibGit2.GitRepo(".")
  # LibGit2.add!(repo, filename)
  # sig = LibGit2.Signature("Script on behalf of Omar", "elrefaei.omar@gmail.com")
  # commit_msg = "update WKT dataset to $version"
  # LibGit2.commit(repo, commit_msg; author=sig, committer=sig)
  # # tag this commit
  # commit_oid = LibGit2.head_oid(repo)
  # LibGit2.create_tag(repo, "latest", commit_oid, force=true)
  # # LibGit2.push(repo)
  # finalize(repo)
end

function get_dataset_zip(path::String)
  isfile(path) || throw(ArgumentError("File not found: $path"))
  html_string = String(read(open("path")))
  html = parsehtml(html_string)
  get_dataset_zip(html)
end
