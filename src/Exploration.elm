module Exploration exposing (..)

import Browser
import Html exposing (Html, div, input, text, button)
import Html.Attributes exposing (id, placeholder, value)
import Html.Events exposing (onInput, onClick)
import Force exposing (entity, computeSimulation, manyBody, simulation, links, center)
import Svg exposing (Svg, svg, circle, line, rect)
import Svg.Attributes exposing (width, height, viewBox, cx, cy, r, x1, y1, x2, y2, style, transform)
import Svg.Events exposing (on, onMouseUp, onMouseOut)
import Json.Decode exposing (Decoder, int, map, field, map2)

-- MAIN

main =
  Browser.sandbox { init = init, update = update, view = view }

-- MODEL

type Model = Model Graph QuestionQuery Viewport


init : Model
init =
  Model (initializeGraph initNoteData initLinkData) (Shown "") initializeViewport

initNoteData : List Note
initNoteData = 
  [ Note 1 "What is the Elm langauge?" "" "index"
  , Note 2 "Why does some food taste better than others?" "" "index"
  , Note 3 "Note 0" "" "note"]

initLinkData: List LinkRecord
initLinkData =
  [
    LinkRecord 1 3 1
  ]

-- GRAPH
type Graph = Graph Notes Links

initializeGraph: (List Note) -> (List LinkRecord) -> Graph
initializeGraph notes links =
  Graph (initializeNotes notes links) (initializeLinks links)

getNotes: Graph -> (List PositionNote)
getNotes graph =
  case graph of
    Graph notes _ ->
      case notes of
        Notes positionNotes -> positionNotes

getLinkViews: Graph -> List LinkView
getLinkViews graph =
  case graph of
    Graph notes links ->
      case links of
        Links linkList -> 
          List.map (\link -> linkToLinkView link notes) linkList 

-- NOTES
type Notes = Notes (List PositionNote)
type alias PositionNote =
  { id : NoteId
  , content : Content
  , source : Source
  , noteType: NoteType
  , x : Float
  , y : Float
  , vx : Float
  , vy : Float
  }

type alias Note = 
  { id : NoteId
  , content : Content
  , source : Source
  , noteType: String
  }

type alias NoteId = Int
type alias Content = String
type NoteType = Regular | Index
type alias Source = String

initializeNotes: (List Note) -> (List LinkRecord) -> Notes
initializeNotes notes links =
  Notes (initSimulation (List.indexedMap initializePosition notes) links)

initSimulation: (List PositionNote) -> (List LinkRecord) -> (List PositionNote)
initSimulation notes linkRecords =
  let
    state = 
      simulation 
        [ manyBody (List.map (\n -> n.id) notes)
        , links (List.map (\l -> (l.source, l.target)) linkRecords)
        , center 0 0
        ]
  in
    computeSimulation state notes

initializePosition: Int -> Note -> PositionNote
initializePosition index note =
  let
    positions = entity index 1
  in
    PositionNote note.id note.content note.source (noteType note.noteType) positions.x positions.y positions.vx positions.vy

noteType: String -> NoteType
noteType s =
  if s == "index" then
    Index
  else
    Regular

findNote: NoteId -> Notes -> Maybe PositionNote
findNote id n =
  case n of
    Notes noteList ->
      List.head (List.filter (\note -> note.id == id) noteList)

-- LINKS
type Links = Links (List Link)
type alias Link = 
  { source: NoteId
  , target: NoteId
  , id: LinkId
  }

type alias LinkRecord =
  { source: NoteId
  , target: NoteId
  , id: LinkId
  }

type alias LinkId = Int

initializeLinks: (List LinkRecord) -> Links
initializeLinks l =
  Links (List.map (\lr -> Link lr.source lr.target lr.id) l)

type LinkView = 
  BadLink |
  LinkView LinkViewRecord

type alias LinkViewRecord = 
  { sourceId: NoteId
  , sourceX: Float
  , sourceY: Float
  , targetId: NoteId
  , targetX: Float
  , targetY: Float
  , id: LinkId
  }

linkToLinkView: Link -> Notes -> LinkView
linkToLinkView link notes =
  let
    maybeSource = findNote link.source notes
    maybeTarget = findNote link.target notes
    maybeLinkViewRecord = Maybe.map3 linkViewRecord maybeSource maybeTarget (Just link.id)
  in
    case maybeLinkViewRecord of
      Just r -> LinkView r
      Nothing -> BadLink
    

linkViewRecord: PositionNote -> PositionNote -> LinkId -> LinkViewRecord
linkViewRecord source target id =
  LinkViewRecord source.id source.x source.y target.id target.x target.y id

-- QuestionFilter
type QuestionQuery = 
  Shown String |
  Hidden String

reverseQuestionQueryState: QuestionQuery -> QuestionQuery
reverseQuestionQueryState q =
  case q of
    Shown s -> Hidden s
    Hidden s -> Shown s

updateQuestionQuery: String -> QuestionQuery -> QuestionQuery
updateQuestionQuery s q =
  case q of
    Shown _ -> Shown s
    Hidden _ -> Hidden s

-- VIEWPORT
type Viewport = 
  Resting Viewbox |
  Moving Viewbox MouseCoordinates

type alias Viewbox = 
  { minX: Int
  , minY: Int
  , length: Int
  , width: Int
  }

svgWidth: Int
svgWidth = 800

svgLength: Int
svgLength = 800

type alias MouseCoordinates = (Int, Int)

initializeViewport: Viewport
initializeViewport =
  Resting (Viewbox -200 -200 400 400)

getViewbox: Viewport -> String
getViewbox viewport =
  case viewport of
    Resting box -> assembleViewbox box
    Moving box _ -> assembleViewbox box

assembleViewbox: Viewbox -> String
assembleViewbox box =
   String.fromInt box.minX ++ " " ++  String.fromInt box.minY ++ " " ++  String.fromInt box.width ++ " " ++  String.fromInt box.length

updateViewportMouseDown: MouseEvent -> Viewport -> Viewport
updateViewportMouseDown mouseEvent viewport =
  case viewport of
    Resting box -> Moving box (mouseEvent.offsetX, mouseEvent.offsetY)
    Moving box coordinates ->  Moving (updateViewbox mouseEvent coordinates box) (mouseEvent.offsetX, mouseEvent.offsetY)

updateViewportMouseMove: MouseEvent -> Viewport -> Viewport
updateViewportMouseMove mouseEvent viewport =
  case viewport of
    Resting box -> Resting box
    Moving box coordinates ->  Moving (updateViewbox mouseEvent coordinates box) (mouseEvent.offsetX, mouseEvent.offsetY)

updateViewbox: MouseEvent -> (Int, Int) -> Viewbox -> Viewbox
updateViewbox mouseEvent priorCoords viewbox =
  let
    xChange = Tuple.first priorCoords - mouseEvent.offsetX
    yChange = Tuple.second priorCoords - mouseEvent.offsetY
  in
    Viewbox (calcXCoord viewbox xChange) (calcYCoord viewbox yChange) viewbox.length viewbox.width

zoomIn: Viewport -> Viewport
zoomIn viewport =
  case viewport of
    Resting viewbox -> Resting (zoomInViewbox viewbox)
    Moving _ _ -> viewport

zoomInViewbox: Viewbox -> Viewbox
zoomInViewbox viewbox =
  let
    newWidthHeight = viewbox.width - 100
    edgeConstraint = 300
  in
    if newWidthHeight < edgeConstraint then
      Viewbox viewbox.minX viewbox.minY edgeConstraint edgeConstraint
    else
      Viewbox viewbox.minX viewbox.minY newWidthHeight newWidthHeight
  
zoomOut: Viewport -> Viewport
zoomOut viewport =
  case viewport of
    Resting viewbox -> Resting (zoomOutViewbox viewbox)
    Moving _ _ -> viewport

zoomOutViewbox: Viewbox -> Viewbox
zoomOutViewbox viewbox = 
  let
    shouldCalcX = shouldCalcXCoordinate viewbox
    shouldCalcY = shouldCalcYCoordinate viewbox
    change = 10
  in
    if shouldCalcX && shouldCalcY then
      Viewbox (calcXCoord viewbox change) (calcYCoord viewbox change) (expandLength viewbox.length) (expandWidth viewbox.width)
    else if shouldCalcX then
      Viewbox (calcXCoord viewbox change) viewbox.minY (expandLength viewbox.length) (expandWidth viewbox.width)
    else if shouldCalcY then
      Viewbox viewbox.minX (calcYCoord viewbox change) (expandLength viewbox.length) (expandWidth viewbox.width)
    else
      Viewbox viewbox.minX viewbox.minY (expandLength viewbox.length) (expandWidth viewbox.width)

expandWidth: Int -> Int
expandWidth edge =
  if edge + 100 > svgWidth then  
    svgWidth
  else
    edge + 100

expandLength: Int -> Int
expandLength edge =
  if edge + 100 > svgLength then  
    svgLength
  else
    edge + 100

shouldCalcXCoordinate: Viewbox -> Bool
shouldCalcXCoordinate viewbox =
  viewbox.width + viewbox.minX > floor ( toFloat svgWidth / 2)

shouldCalcYCoordinate: Viewbox -> Bool
shouldCalcYCoordinate viewbox =
  viewbox.length + viewbox.minY > floor ( toFloat svgLength / 2)

calcXCoord: Viewbox -> Int -> Int
calcXCoord viewbox change =
  let
    newMinX = viewbox.minX - (change * 10)
  in
    if newMinX + viewbox.width > floor (toFloat svgWidth / 2) then
      viewbox.minX
    else if newMinX < negate (floor(toFloat svgWidth / 2)) then
      viewbox.minX
    else
      newMinX

calcYCoord: Viewbox -> Int -> Int
calcYCoord viewbox change =
  let
    newMinY = viewbox.minY - (change * 10)
  in
    if newMinY + viewbox.length > floor (toFloat svgLength / 2) then
      viewbox.minY
    else if newMinY < negate (floor(toFloat svgWidth / 2)) then
      viewbox.minY
    else
      newMinY  

restViewport: Viewport -> Viewport
restViewport viewport =
  case viewport of
    Resting box -> Resting box
    Moving box _ -> Resting box

getCursorStyle: Viewport -> String
getCursorStyle viewport =
  case viewport of
    Resting _ -> "cursor: grab;"
    Moving _ _ -> "cursor: grabbing;"

panningSquareTranslation: Viewport -> String
panningSquareTranslation viewport =
  case viewport of 
    Resting viewbox -> viewBoxToTranslation viewbox
    Moving viewbox _ -> viewBoxToTranslation viewbox

viewBoxToTranslation: Viewbox -> String
viewBoxToTranslation viewbox =
  let
    x = toFloat (viewbox.minX + 400) / 10
    y = toFloat (viewbox.minY + 400) / 10
  in
    "translate(" ++ String.fromFloat x ++ "," ++ String.fromFloat y ++ ")"

panningWidth: Viewport -> String
panningWidth viewport =
  case viewport of
    Resting viewbox -> String.fromInt (floor (toFloat viewbox.width / 10))
    Moving viewbox _ -> String.fromInt (floor (toFloat viewbox.width / 10))

panningHeight: Viewport -> String
panningHeight viewport =
  case viewport of
    Resting viewbox -> String.fromInt (floor (toFloat viewbox.length / 10))
    Moving viewbox _ -> String.fromInt (floor (toFloat viewbox.length / 10))

-- UPDATE

type Msg = 
  Change String |
  ShowQuestionList |
  MouseMove MouseEvent |
  MouseDown MouseEvent |
  MouseUp |
  MouseOut |
  ZoomIn |
  ZoomOut

update : Msg -> Model -> Model
update msg model =
  case model of
    Model graph query viewport->
      case msg of 
        ShowQuestionList -> Model graph (reverseQuestionQueryState query) viewport
        Change str -> Model graph (updateQuestionQuery str query) viewport
        MouseUp -> Model graph query (restViewport viewport)
        MouseDown e -> Model graph query (updateViewportMouseDown e viewport)
        MouseMove e -> Model graph query (updateViewportMouseMove e viewport)
        MouseOut -> Model graph query (restViewport viewport)
        ZoomIn -> Model graph query (zoomIn viewport)
        ZoomOut -> Model graph query (zoomOut viewport)

-- VIEW
view : Model -> Html Msg
view m =
  div []
    [ div [id "Graph-container", style "padding: 16px; border: 4px solid black"] 
      [ questionView m, graphView m, panningVisual m, zoomOutButton, zoomInButton]
    , div [id "History-Queue"] [ text "History Queue"]
    ]

graphView: Model -> Svg Msg
graphView m =
  case m of
    Model graph _ viewport -> 
      svg
        [ width "800"
        , height "800"
        , viewBox (getViewbox viewport)
        , style "border: 4px solid black;"
        ]
        ( List.map noteCircles (getNotes graph) ++
         List.map linkLine (getLinkViews graph))

panningVisual: Model -> Svg Msg
panningVisual m =
  case m of
    Model _ _ viewport ->
      svg 
        [ width "80" 
        , height "80"
        , style "border: 4px solid black;"
        ] 
        [
          rect 
            [ width (panningWidth viewport)
            , height (panningHeight viewport)
            , style ("fill:rgb(220,220,220);stroke-width:3;stroke:rgb(0,0,0);" ++ getCursorStyle viewport)
            , transform (panningSquareTranslation viewport)
            , on "mousemove" mouseMoveDecoder
            , on "mousedown" mouseDownDecoder
            , onMouseUp MouseUp
            , onMouseOut MouseOut
            ] 
            []
        ]

linkLine: LinkView -> Svg Msg
linkLine lv =
  case lv of
    BadLink -> line [] []
    LinkView lvr ->
      line 
        [x1 (String.fromFloat lvr.sourceX)
        , y1 (String.fromFloat lvr.sourceY)
        , x2 (String.fromFloat lvr.targetX)
        , y2 (String.fromFloat lvr.targetY)
        , style "stroke:rgb(0,0,0);stroke-width:2"
        ] 
        []

noteCircles: PositionNote -> Svg Msg
noteCircles pn =
  let
    color = noteColor pn.noteType
    fill = "fill:" ++ color ++ ";"
    styleString = "Cursor:Pointer;" ++ fill
  in
    circle 
      [ cx (String.fromFloat pn.x)
      , cy (String.fromFloat pn.y) 
      , r "5"
      , style styleString
      ]
      []
  
questionView : Model -> Html Msg
questionView m =
  case m of 
    Model graph q _ ->
      case q of
        Shown query -> div [] 
          [ questionFilter query
          , div [id "Question List", style "border: 4px solid black; padding: 16px;"] (questionList graph query)
          , questionButton
          ]
        Hidden _ -> questionButton

zoomInButton: Html Msg
zoomInButton =
  button [ onClick ZoomIn ] [ text "+" ]

zoomOutButton: Html Msg
zoomOutButton =
  button [ onClick ZoomOut ] [ text "-" ]

questionButton: Html Msg
questionButton = 
  button [ id "Show Question Button", onClick ShowQuestionList ] [ text "Q" ]

questionFilter: String -> Html Msg 
questionFilter s = 
  input [placeholder "Find Note", value s, onInput Change] []

questionList: Graph -> String -> List (Html Msg)
questionList graph query =
  graph 
    |> getNotes 
    |> List.filter (\note -> String.contains query note.content)
    |> List.map divFromNote 

divFromNote: PositionNote -> Html Msg
divFromNote v =
  let 
    color = noteColor v.noteType
    backgroundColor = "background-color:" ++ color ++ ";"
    styleString = "border: 1px solid black;margin-bottom: 16px;cursor:pointer;" ++ backgroundColor
  in
    div [style styleString] [text v.content]

noteColor: NoteType -> String
noteColor notetype =
  case notetype of
    Regular -> "rgba(137, 196, 244, 1)"
    Index -> "rgba(250, 190, 88, 1)"

type alias MouseEvent =
    { offsetX : Int
    , offsetY : Int
    }

offsetXDecoder: Decoder Int
offsetXDecoder = 
  field "offsetX" int

offsetYDecoder: Decoder Int
offsetYDecoder =
  field "offsetY" int

mouseEventDecoder: Decoder MouseEvent
mouseEventDecoder =
  map2 MouseEvent offsetXDecoder offsetYDecoder

mouseMoveDecoder: Decoder Msg
mouseMoveDecoder =
  map MouseMove mouseEventDecoder

mouseDownDecoder: Decoder Msg
mouseDownDecoder =
  map MouseDown mouseEventDecoder