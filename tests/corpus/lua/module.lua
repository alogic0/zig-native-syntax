local renderer = {}

function renderer.render(document, options)
    local title = options.title or "Untitled"
    print(title, document.body)
    return [=[<main class="content">]=] .. document.body .. "</main>"
end

return renderer
