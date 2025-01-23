-- Author: Kaffeekirsche
-- Name: fieldBorderToSpline
-- Description: Converts the field points into a spline
-- Icon:
-- Hide: no
-- AlwaysLoaded: no
-- Function to create a spline from transform groups

source("editorUtils.lua")
source("map/farmlandFields/fieldUtil.lua")

-- Build the class
FieldToSplineConverter = {}
local coordinates = {}
local rootNode = getRootNode()


-- Centralized logging function
local function log(message)
    print(message)
    -- Optional: Log to a file
    local logFile = createFile("conversion_log.txt", 0)
    fileWrite(logFile, message .. "\n")
    delete(logFile)
end

local function safeFileWrite(file, content)
    local success, errorMsg = pcall(function()
        fileWrite(file, content)
    end)
    if not success then
        log("Error writing to file: " .. errorMsg)
    end
end

-- Function to collect coordinates of child nodes
local function collectChildCoordinates(node)
    if node == nil then return end

    local numChildren = getNumOfChildren(node)
    for i = 1, numChildren do  -- Use index from 1
        local childNode = getChildAt(node, i - 1)  -- Adjust index here
        local x, y, z = getTranslation(childNode)
        table.insert(coordinates, {name = getName(childNode), x = x, y = y, z = z})
    end
end

-- Function to find a node by name
local function getNodeByName(name)
    local rootNode = getSelection(0)
    if not rootNode then
        log("No root node selected.")
        return nil
    end

    -- Check if root node's name starts with "field"
    if getName(rootNode):sub(1, 5) ~= "field" then
        log(string.format("Error: The node name '%s' does not start with 'field'.", getName(rootNode)))
        return nil
    end

    -- Search for the child node by name
    local numChildren = getNumOfChildren(rootNode)
    for i = 0, numChildren - 1 do
        local childNode = getChildAt(rootNode, i)
        if getName(childNode) == name then
            return childNode
        end
    end
    return nil
end

local function findChildByName(parentNode, name)
    local numChildren = getNumOfChildren(parentNode)
    for i = 0, numChildren - 1 do
        local child = getChildAt(parentNode, i)
        if getName(child) == name then
            return child
        end
    end
    return nil
end

-- Try to find the node "polygonPoints"
local selectedNode = getNodeByName("polygonPoints")
if not selectedNode then
    log("No node with the name 'polygonPoints' found.")
else
    log("Node 'polygonPoints' selected.")
end

if selectedNode then
    log("Collecting coordinates of child objects...")
    collectChildCoordinates(selectedNode)

    local objName = getName(getSelection(0))
    local splineCheck = getNumOfChildren(selectedNode) > 0
    local splineName = objName or "field_" .. tostring(math.random(1, 100))

    if not splineCheck then
        log(string.format("\nERROR: OBJECT :-- %s --IS EMPTY", objName))
    end

    -- Ensure splineName is not nil
    if not splineName then
        log("ERROR: splineName is nil!")
        return nil
    end

    -- Get scene file path
    local fileName = getSceneFilename()
    local newStr = fileName:sub(1, fileName:find("/[^/]*$"))
    local genSplineFolder = newStr .. "fieldSplines/"

    -- Check if temp folder exists, create if not
    if not fileExists(genSplineFolder) then
        createFolder(genSplineFolder)
    end

    -- Set file paths
    local filenameI3D = genSplineFolder .. splineName .. "_spline.i3d"
    local splineFile = createFile(filenameI3D, 0)
    if not splineFile then
        log("ERROR: Unable to create the i3d file!")
        return false -- Statt return nil, könnte man auch false zurückgeben, falls man den Status kontrollieren möchte
    end
    log("i3d file created successfully!")

    -- XML header for the i3D file
    local xmlTop = string.format("<?xml version=%q encoding=%q?>\n", "1.0", "iso-8859-1")
    local xmlOne = string.format("<i3D name=%q version=%q xmlns:xsi=%q xsi:noNamespaceSchemaLocation=%q>\n", splineName .. "_spline", "1.6", "http://www.w3.org/2001/XMLSchema-instance", "http://i3d.giants.ch/schema/i3d-1.6.xsd")
    local xmlTwo = string.format("       <Asset>\n         <Export program=%q version=%q/>\n       </Asset>\n", "Field Points to Spline Converter by Kaffeekirsche", "1.0 (22-01-2025)")
    local xmlThree = string.format("    <Shapes>\n         <NurbsCurve name=%q shapeId=%q degree=%q form=%q>", splineName .. "_spline", "11", "3", "open")
    local xmlFour = string.format("\n         </NurbsCurve>\n    </Shapes>\n    <Scene>\n         <Shape name=%q translation=%q nodeId=%q shapeId=%q/>\n    </Scene>  \n</i3D>", splineName .. "_spline", "0 0 0", "11", "11")

    -- Write XML, i3d and txt
    local xmlContent = table.concat({xmlTop, xmlOne, xmlTwo, xmlThree}, "")
    safeFileWrite(splineFile, xmlContent)

    local splineContent = {}
    for i, coord in ipairs(coordinates) do
        local csvPos = string.format("%f, %f, %f", coord.x, coord.y, coord.z)
        table.insert(splineContent, string.format("\n              <cv c=%q />", csvPos))
    end

    -- Jetzt alle in einer Operation schreiben:
    safeFileWrite(splineFile, table.concat(splineContent))

    -- Close the Files
    safeFileWrite(splineFile, xmlFour)

    local existingNode = findChildByName(rootNode, splineName .. "_spline")
    if existingNode ~= nil then
        log("The i3D file is already loaded. Reloading...")
        delete(existingNode)
    else
        log("The i3D file is not loaded. Importing...")
    end

     -- Load the created i3D file as reference
    log("Loading the created i3D file...")
    local loadedNode = createI3DReference(filenameI3D, false, false)
    if loadedNode ~= 0 then
        link(rootNode, loadedNode)
        log("Successfully loaded and linked the i3D file to the rootNode.")
    else
        log("Failed to load the i3D file.")
    end

    delete(splineFile)
    log("Process completed successfully!")
else
    log("No object selected.")
end