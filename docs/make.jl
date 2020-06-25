using Documenter, DistributedLogging

makedocs(;
    modules=[DistributedLogging],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://gitlab.invenia.ca/invenia/DistributedLogging.jl/blob/{commit}{path}#L{line}",
    sitename="DistributedLogging.jl",
    authors="Invenia Technical Computing Corporation",
    assets=[
        "assets/invenia.css",
        "assets/logo.png",
    ],
    strict=true,
    html_prettyurls=false,
    checkdocs=:none,
)
