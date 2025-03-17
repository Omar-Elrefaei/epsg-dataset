using HTTP, Cascadia, Gumbo

# Step 1: request login form and extract tokens
resp = HTTP.get("https://epsg.org/account/login/")

loginpage = resp.body |> String |> parsehtml;
ms = eachmatch(sel"input[name='__RequestVerificationToken']", loginpage.root);
@assert !isempty(ms) "Couldn't find RequestVerificationToken, login process might have changed"
verification_token = ms[1].attributes["value"]

ms = eachmatch(sel"[id='ReturnUrl']", loginpage.root);
@assert !isempty(ms) "Couldn't find ReturnUrl, login process might have changed"
returnurl = ms[1].attributes["value"]
amp_unescaped = replace(returnurl, "&amp;" => "&")
amp_unescaped_uri_esc = HTTP.URIs.escapeuri(amp_unescaped)

# Step 2: login by submitting password along with token
headers = Dict(
    "content-type" => "application/x-www-form-urlencoded",
)

body = Dict(
    "ReturnUrl" => amp_unescaped,
    "Username" => "elrefaei.omar@gmail.com",
    "Password" => "Component8@Clause@Unraveled",
    "button" => "login",
    "__RequestVerificationToken" =>verification_token,
    "RememberLogin" => "false"
)

login_resp = HTTP.post(
    "https://epsg.org/auth/Account/Login?$amp_unescaped_uri_esc",
    headers, body,
    redirect_limit = 7, status_exception = false,
)
@assert login_resp.status == 200


import AbstractTrees.PreOrderDFS
# Step 3: process response and handshake confirmation
#the previous request responds with a small pre-populated HTML Form that is auto submitted when working in a browser. 
#We process it into a Dict and send it back in as a "body" since HTTP.jl takes care to converting that into a Form submission
function parse_form_data(html)
    form_data = Dict{String,String}()
    for elem in PreOrderDFS(html.root)
        if isa(elem, HTMLElement{:input})
            name = get(elem.attributes, "name", nothing)
            value = get(elem.attributes, "value", nothing)
            form_data[name] = value
        end
    end
    return form_data
end

form_data = parse_form_data(login_resp.body |> String |> parsehtml)

headers = Dict(
    "Content-Type" => "application/x-www-form-urlencoded",
)
response = HTTP.post(
    "https://epsg.org/account/login", # from the Form's action attribute
    headers, form_data
)

