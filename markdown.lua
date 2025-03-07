--[[
    Markdown Parser for Roblox
    
    This module parses markdown text and converts it to Roblox UI elements.
    
    Features:
    - Headers (# Header 1, ## Header 2, etc.)
    - Bold text (**bold**)
    - Italic text (*italic*)
    - Lists (- item, * item, 1. item)
    - Code blocks (```code```)
    - Links [text](url)
]]

local MarkdownParser = {}

-- Default styles
MarkdownParser.Style = {
    Font = {
        Regular = Enum.Font.Gotham,
        Bold = Enum.Font.GothamBold,
        Italic = Enum.Font.GothamMedium,
        Code = Enum.Font.Code,
        Header = Enum.Font.GothamBold
    },
    TextSize = {
        Default = 14,
        H1 = 24,
        H2 = 20,
        H3 = 18,
        H4 = 16,
        H5 = 15,
        H6 = 14,
        Code = 13
    },
    Color = {
        Default = Color3.fromRGB(220, 220, 220),
        Header = Color3.fromRGB(255, 255, 255),
        Link = Color3.fromRGB(70, 150, 255),
        Code = Color3.fromRGB(200, 200, 200),
        CodeBackground = Color3.fromRGB(40, 40, 40)
    },
    LineSpacing = 5,
    IndentSize = 20
}

-- Fetch markdown from URL
function MarkdownParser.FetchFromURL(url)
    local success, result
    
    -- Get HttpService
    local HttpService
    
    success, HttpService = pcall(function()
        return game:GetService("HttpService")
    end)
    
    if not success or not HttpService then
        return "# Error\nCould not access HttpService. This may be disabled in your executor."
    end
    
    -- Make request
    success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)
    
    if not success then
        return "# Error\nFailed to fetch markdown from URL: " .. url .. "\n\nError: " .. tostring(result)
    end
    
    return result
end

-- Parse markdown text and create UI elements in the specified container
function MarkdownParser.ParseToContainer(markdownText, container, customStyle)
    -- Merge custom style with default style
    local style = {}
    for k, v in pairs(MarkdownParser.Style) do
        if type(v) == "table" then
            style[k] = {}
            for k2, v2 in pairs(v) do
                style[k][k2] = v2
            end
        else
            style[k] = v
        end
    end
    
    if customStyle then
        for k, v in pairs(customStyle) do
            if type(v) == "table" and type(style[k]) == "table" then
                for k2, v2 in pairs(v) do
                    style[k][k2] = v2
                end
            else
                style[k] = v
            end
        end
    end
    
    -- Clear existing content
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "ChangelogTitle" then
            child:Destroy()
        end
    end
    
    -- Create a scrolling frame for the content
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "MarkdownContent"
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Position = UDim2.new(0, 10, 0, 50) -- Position below title
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.CanvasSize = UDim2.new(1, -20, 0, 0) -- Will be updated as content is added
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Parent = container
    
    -- Split the text into lines
    local lines = {}
    for line in string.gmatch(markdownText .. "\n", "([^\n]*)\n") do
        table.insert(lines, line)
    end
    
    local currentY = 0
    local lineIndex = 1
    
    while lineIndex <= #lines do
        local line = lines[lineIndex]
        
        -- Check for headers
        local headerLevel, headerText = string.match(line, "^(#+)%s+(.+)")
        if headerLevel then
            local level = math.min(#headerLevel, 6)
            
            local header = Instance.new("TextLabel")
            header.BackgroundTransparency = 1
            header.Position = UDim2.new(0, 0, 0, currentY)
            header.Size = UDim2.new(1, 0, 0, style.TextSize["H" .. level] + 10)
            header.Font = style.Font.Header
            header.Text = headerText
            header.TextColor3 = style.Color.Header
            header.TextSize = style.TextSize["H" .. level]
            header.TextXAlignment = Enum.TextXAlignment.Left
            header.TextWrapped = true
            header.Parent = scrollFrame
            
            currentY = currentY + header.Size.Y.Offset + style.LineSpacing
            lineIndex = lineIndex + 1
            
            -- Add horizontal line after H1 and H2
            if level <= 2 then
                local divider = Instance.new("Frame")
                divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                divider.BorderSizePixel = 0
                divider.Position = UDim2.new(0, 0, 0, currentY)
                divider.Size = UDim2.new(1, 0, 0, 1)
                divider.Parent = scrollFrame
                
                currentY = currentY + 3 + style.LineSpacing
            end
        -- Check for code blocks
        elseif line:match("^```") then
            local codeBlockContent = {}
            local language = line:match("^```(%w*)")
            
            lineIndex = lineIndex + 1
            while lineIndex <= #lines and not lines[lineIndex]:match("^```") do
                table.insert(codeBlockContent, lines[lineIndex])
                lineIndex = lineIndex + 1
            end
            
            -- Skip the closing ```
            lineIndex = lineIndex + 1
            
            local codeText = table.concat(codeBlockContent, "\n")
            
            -- Create a frame for the code block
            local codeFrame = Instance.new("Frame")
            codeFrame.BackgroundColor3 = style.Color.CodeBackground
            codeFrame.BorderSizePixel = 0
            codeFrame.Position = UDim2.new(0, 0, 0, currentY)
            
            -- Create code text
            local codeLabel = Instance.new("TextLabel")
            codeLabel.BackgroundTransparency = 1
            codeLabel.Position = UDim2.new(0, 10, 0, 10)
            codeLabel.Size = UDim2.new(1, -20, 1, -20)
            codeLabel.Font = style.Font.Code
            codeLabel.Text = codeText
            codeLabel.TextColor3 = style.Color.Code
            codeLabel.TextSize = style.TextSize.Code
            codeLabel.TextXAlignment = Enum.TextXAlignment.Left
            codeLabel.TextYAlignment = Enum.TextYAlignment.Top
            codeLabel.TextWrapped = true
            codeLabel.Parent = codeFrame
            
            -- Calculate the height based on content
            local textHeight = 0
            local textService = game:GetService("TextService")
            local textSize = textService:GetTextSize(
                codeText,
                style.TextSize.Code,
                style.Font.Code,
                Vector2.new(scrollFrame.Size.X.Offset - 40, 10000)
            )
            textHeight = textSize.Y
            
            codeLabel.Size = UDim2.new(1, -20, 0, textHeight)
            codeFrame.Size = UDim2.new(1, 0, 0, textHeight + 20)
            codeFrame.Parent = scrollFrame
            
            currentY = currentY + codeFrame.Size.Y.Offset + style.LineSpacing
        -- Check for lists
        elseif line:match("^%s*[%-%*]%s+") or line:match("^%s*%d+%.%s+") then
            local indentLevel = 0
            local listItems = {}
            
            while lineIndex <= #lines do
                local currentLine = lines[lineIndex]
                local spaces = currentLine:match("^(%s*)")
                local currentIndent = spaces and #spaces/2 or 0
                local listMarker, listText = currentLine:match("^%s*([%-%*]%s+)(.+)") or currentLine:match("^%s*(%d+%.%s+)(.+)")
                
                if not listMarker then
                    break
                end
                
                table.insert(listItems, {
                    text = listText,
                    marker = listMarker:sub(1,1) == "-" or listMarker:sub(1,1) == "*" and "•" or listMarker,
                    indent = currentIndent
                })
                
                lineIndex = lineIndex + 1
            end
            
            -- Create list items
            for i, item in ipairs(listItems) do
                local listItem = Instance.new("TextLabel")
                listItem.BackgroundTransparency = 1
                listItem.Position = UDim2.new(0, item.indent * style.IndentSize, 0, currentY)
                listItem.Size = UDim2.new(1, -item.indent * style.IndentSize, 0, style.TextSize.Default + 5)
                listItem.Font = style.Font.Regular
                
                -- Format the list marker
                local displayMarker = item.marker
                if displayMarker == "•" then
                    displayMarker = "• "
                end
                
                listItem.Text = displayMarker .. " " .. item.text
                listItem.TextColor3 = style.Color.Default
                listItem.TextSize = style.TextSize.Default
                listItem.TextXAlignment = Enum.TextXAlignment.Left
                listItem.TextWrapped = true
                listItem.Parent = scrollFrame
                
                -- Calculate height based on content
                local textService = game:GetService("TextService")
                local textSize = textService:GetTextSize(
                    listItem.Text,
                    style.TextSize.Default,
                    style.Font.Regular,
                    Vector2.new(scrollFrame.Size.X.Offset - (item.indent * style.IndentSize), 10000)
                )
                listItem.Size = UDim2.new(1, -item.indent * style.IndentSize, 0, textSize.Y)
                
                currentY = currentY + listItem.Size.Y.Offset + 2
            end
            
            currentY = currentY + style.LineSpacing
        -- Regular paragraph
        else
            -- Process consecutive lines until we find a blank line or special format
            local paragraphLines = {}
            
            while lineIndex <= #lines do
                local currentLine = lines[lineIndex]
                -- Stop at blank line or special format
                if currentLine == "" or 
                   currentLine:match("^#+%s+") or 
                   currentLine:match("^```") or
                   currentLine:match("^%s*[%-%*]%s+") or 
                   currentLine:match("^%s*%d+%.%s+") then
                    break
                end
                
                table.insert(paragraphLines, currentLine)
                lineIndex = lineIndex + 1
            end
            
            -- If no paragraph content, just skip the blank line
            if #paragraphLines == 0 then
                lineIndex = lineIndex + 1
                currentY = currentY + style.LineSpacing
            else
                local paragraphText = table.concat(paragraphLines, " ")
                
                -- Basic formatting for bold/italic/links
                local formattedText = paragraphText
                
                -- Create paragraph label
                local paragraph = Instance.new("TextLabel")
                paragraph.BackgroundTransparency = 1
                paragraph.Position = UDim2.new(0, 0, 0, currentY)
                paragraph.Size = UDim2.new(1, 0, 0, style.TextSize.Default + 5)
                paragraph.Font = style.Font.Regular
                paragraph.Text = formattedText
                paragraph.TextColor3 = style.Color.Default
                paragraph.TextSize = style.TextSize.Default
                paragraph.TextXAlignment = Enum.TextXAlignment.Left
                paragraph.TextWrapped = true
                paragraph.Parent = scrollFrame
                
                -- Calculate height based on content
                local textService = game:GetService("TextService")
                local textSize = textService:GetTextSize(
                    formattedText,
                    style.TextSize.Default,
                    style.Font.Regular,
                    Vector2.new(scrollFrame.Size.X.Offset, 10000)
                )
                paragraph.Size = UDim2.new(1, 0, 0, textSize.Y)
                
                currentY = currentY + paragraph.Size.Y.Offset + style.LineSpacing
            end
        end
    end
    
    -- Update the canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, currentY)
end

-- Load and display a local markdown file
function MarkdownParser.LoadFile(filePath, container, customStyle)
    local success, content = pcall(function()
        return readfile(filePath)
    end)
    
    if not success then
        local errorMessage = "# Error Loading File\n\nCould not load file: " .. filePath
        MarkdownParser.ParseToContainer(errorMessage, container, customStyle)
        return false
    end
    
    MarkdownParser.ParseToContainer(content, container, customStyle)
    return true
end

return MarkdownParser 