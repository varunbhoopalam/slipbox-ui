module Slipbox exposing (Slipbox, LinkRecord, initialize, 
  selectNote, dismissNote, stopHoverNote, searchSlipbox, SearchResult,
  getGraphElements, GraphNote, GraphLink, getSelectedNotes, DescriptionNote
  , DescriptionLink, hoverNote, CreateNoteRecord, CreateLinkRecord
  , HistoryAction, getHistory, createNote, MakeNoteRecord, MakeLinkRecord
  , createLink, sourceSelected, targetSelected, getLinkFormData)

import Simulation
import LinkForm
import Note

--Types
type Slipbox = Slipbox (List Note.Note) (List Link) (List Action) LinkForm.LinkForm

type alias Link = 
  { source: Int
  , target: Int
  , id: LinkId
  }

type Action =
  CreateNote HistoryId Undone HistoryNote |
  CreateLink HistoryId Undone HistoryLink

type alias HistoryId = Int

type alias Undone = Bool

type alias HistoryNote =
  { id : Int
  , content : String
  , source : String
  , noteType: String
  }

type alias HistoryLink =
  { source: Int
  , target: Int
  , id: Int
  }

type alias HistoryAction =
  { id : HistoryId
  , undone : Bool
  , summary : String
  }

type alias LinkId = Int

type alias LinkRecord =
  { source: Int
  , target: Int
  , id: Int
  }

type alias MakeLinkRecord =
  { source: Int
  , target: Int
  }

type alias MakeNoteRecord =
  { content : String
  , source : String
  , noteType : String
  }

type alias CreateNoteRecord =
  { id : Int
  , action : Note.NoteRecord
  }

type alias CreateLinkRecord =
  { id : Int
  , action : LinkRecord
  }

type alias SearchResult = 
  { id : Note.NoteId
  , idInt: Int
  , x : Float
  , y : Float
  , variant : String
  , content : String
  }

type alias GraphNote =
  { id: Note.NoteId
  , idInt: Int
  , x : Float
  , y : Float
  , variant : String 
  , shouldAnimate : Bool
  }

type alias GraphLink = 
  { sourceId: Int
  , sourceX: Float
  , sourceY: Float
  , targetId: Int
  , targetX: Float
  , targetY: Float
  , id: LinkId
  }

type alias DescriptionNote =
  { id : Note.NoteId
  , x : Float
  , y : Float 
  , content : String
  , source : String 
  , links : (List DescriptionLink)
  }

type alias DescriptionLink =
  { id : Note.NoteId
  , idInt : Int
  , x : Float
  , y : Float
  }

-- Invariants
summaryLengthMin: Int
summaryLengthMin = 20

-- Methods

-- Returns Slipbox
initialize: (List Note.NoteRecord) -> (List LinkRecord) -> ((List CreateNoteRecord), (List CreateLinkRecord)) -> Slipbox
initialize notes links (noteRecords, linkRecords) =
  let
    l =  initializeLinks links
  in
    Slipbox (initializeNotes notes l) l (initializeHistory (noteRecords, linkRecords)) LinkForm.initLinkForm

selectNote: Note.NoteId -> Slipbox -> Slipbox
selectNote noteId slipbox =
  case slipbox of 
    Slipbox notes links actions form -> handleSelectNote noteId notes links actions form

handleSelectNote: Note.NoteId -> (List Note.Note) -> (List Link) -> (List Action) -> LinkForm.LinkForm -> Slipbox
handleSelectNote noteId notes links actions form =
  let
    newNotes = List.map (selectNoteById noteId) notes
  in
    Slipbox newNotes links actions (LinkForm.selectionsChange form (getFormNotes newNotes links))

dismissNote: Note.NoteId -> Slipbox -> Slipbox
dismissNote noteId slipbox =
  case slipbox of 
    Slipbox notes links actions form -> handleDismissNote noteId notes links actions form

handleDismissNote: Note.NoteId -> (List Note.Note) -> (List Link) -> (List Action) -> LinkForm.LinkForm -> Slipbox
handleDismissNote noteId notes links actions form =
  let
    newNotes = List.map (unselectNoteById noteId) notes
  in 
    Slipbox newNotes links actions (LinkForm.selectionsChange form (getFormNotes newNotes links))

hoverNote: Note.NoteId -> Slipbox -> Slipbox
hoverNote noteId slipbox =
  case slipbox of 
    Slipbox notes links history form-> Slipbox (List.map (hoverNoteById noteId) notes) links history form

stopHoverNote: Slipbox -> Slipbox
stopHoverNote slipbox =
  case slipbox of 
    Slipbox notes links history form -> Slipbox (List.map Note.unHover notes) links history form

createNote: MakeNoteRecord -> Slipbox -> Slipbox
createNote note slipbox =
  case slipbox of
     Slipbox notes links actions form -> handleCreateNote note notes links actions form

handleCreateNote: MakeNoteRecord -> (List Note.Note) -> (List Link) -> (List Action) -> LinkForm.LinkForm -> Slipbox
handleCreateNote makeNoteRecord notes links actions form =
  let
    newNote = toNoteRecord makeNoteRecord notes
    newNoteList = addNoteToNotes newNote notes links
  in
    Slipbox (List.sortWith Note.sortDesc newNoteList) links (addNoteToActions newNote actions) form

createLink: Slipbox -> Slipbox
createLink slipbox =
  case slipbox of 
    Slipbox notes links actions form -> createLinkHandler (LinkForm.maybeProspectiveLink form) notes links actions
  
createLinkHandler: (Maybe (Int, Int)) -> (List Note.Note) -> (List Link) -> (List Action) -> Slipbox
createLinkHandler maybeTuple notes links actions =
  case maybeTuple of
    Just (source, target) -> createLinkHandlerFork (MakeLinkRecord source target) notes links actions
    Nothing -> removeSelectionsFork notes links actions

createLinkHandlerFork: MakeLinkRecord -> (List Note.Note) -> (List Link) -> (List Action) -> Slipbox
createLinkHandlerFork makeLinkRecord notes links actions =
  case toMaybeLink makeLinkRecord links notes of
    Just link -> addLinkToSlipbox link notes links actions
    Nothing -> removeSelectionsFork notes links actions

removeSelectionsFork: (List Note.Note) -> (List Link) -> (List Action) -> Slipbox
removeSelectionsFork notes links actions =
  Slipbox notes links actions (LinkForm.removeSelections (getFormNotes notes links))

addLinkToSlipbox: Link -> (List Note.Note) -> (List Link) -> (List Action) -> Slipbox
addLinkToSlipbox link notes links actions =
  let
    newLinks =  addLinkToLinks link links
  in
    Slipbox 
      (initSimulation notes newLinks)
      newLinks
      (addLinkToActions link actions)
      (LinkForm.removeSelections (getFormNotes notes links))

sourceSelected: String -> Slipbox -> Slipbox
sourceSelected source slipbox =
  case slipbox of
    Slipbox notes links actions form -> Slipbox notes links actions (LinkForm.addSource source form)

targetSelected: String -> Slipbox -> Slipbox
targetSelected target slipbox =
  case slipbox of
    Slipbox notes links actions form -> Slipbox notes links actions (LinkForm.addTarget target form)

-- Publicly Exposed for View
searchSlipbox: String -> Slipbox -> (List SearchResult)
searchSlipbox query slipbox =
  case slipbox of
     Slipbox notes _ _ _-> 
      notes
        |> List.filter (Note.search query)
        |> List.map Note.extract
        |> List.map toSearchResult
  
getGraphElements: Slipbox -> ((List GraphNote), (List GraphLink))
getGraphElements slipbox =
  case slipbox of
    Slipbox notes links _ _ -> 
      ( List.map toGraphNote (List.map Note.extract notes)
      , List.filterMap (\link -> toGraphLink link notes) links)

getSelectedNotes: Slipbox -> (List DescriptionNote)
getSelectedNotes slipbox =
  case slipbox of 
    Slipbox notes links _ _ -> 
      notes
       |> List.filter Note.isSelected
       |> List.map (toDescriptionNote notes links)

getHistory: Slipbox -> (List HistoryAction)
getHistory slipbox =
  case slipbox of
    Slipbox _ _ history _ -> List.map toHistoryAction history

getLinkFormData: Slipbox -> LinkForm.LinkFormData
getLinkFormData slipbox =
  case slipbox of
    Slipbox notes links _ form -> 
      LinkForm.linkFormData (getFormNotes notes links) form

-- Helpers
initializeNotes: (List Note.NoteRecord) -> (List Link) -> (List Note.Note)
initializeNotes notes links =
  sortNotes (initSimulation (List.map Note.init notes) links)

sortNotes: (List Note.Note) -> (List Note.Note)
sortNotes notes =
  List.sortWith Note.sortDesc notes

toSimulationRecord: Note.Extract -> Simulation.SimulationRecord
toSimulationRecord extract =
  Simulation.SimulationRecord extract.intId extract.x extract.y extract.vx extract.vy

toLinkTuple: Link -> (Int, Int)
toLinkTuple link =
  (link.source, link.target)

noteUpdateWrapper: (List Simulation.SimulationRecord) -> Note.Note -> Note.Note
noteUpdateWrapper simRecords note =
  let
    extract = Note.extract note
    maybeSimRecord = List.head (List.filter (\sr -> sr.id == extract.intId) simRecords)
  in
    case maybeSimRecord of
      Just simRecord -> Note.update simRecord note
      Nothing -> note

initSimulation: (List Note.Note) -> (List Link) -> (List Note.Note)
initSimulation notes links =
  let
    simRecords = Simulation.simulate 
      (List.map toSimulationRecord (List.map Note.extract notes))
      (List.map toLinkTuple links)
  in
    List.map (noteUpdateWrapper simRecords) notes

selectNoteById: Note.NoteId -> Note.Note -> Note.Note
selectNoteById noteId note =
  if Note.isNote noteId note then
    Note.select note
  else
    note

unselectNoteById: Note.NoteId -> Note.Note -> Note.Note
unselectNoteById noteId note =
  if Note.isNote noteId note then
    Note.unSelect note
  else
    note

hoverNoteById: Note.NoteId -> Note.Note -> Note.Note
hoverNoteById noteId note =
  if Note.isNote noteId note then
    Note.hover note
  else
    Note.unHover note

toSearchResult: Note.Extract -> SearchResult
toSearchResult extract =
  SearchResult extract.id extract.intId extract.x extract.y extract.variant extract.content

toGraphNote: Note.Extract -> GraphNote
toGraphNote extract =
  GraphNote extract.id extract.intId extract.x extract.y extract.variant extract.selected.hover

initializeLinks: (List LinkRecord) -> (List Link)
initializeLinks linkRecords =
  List.sortWith linkSorterDesc (List.map (\lr -> Link lr.source lr.target lr.id) linkRecords)

linkSorterDesc: (Link -> Link -> Order)
linkSorterDesc linkA linkB =
  case compare linkA.id linkB.id of
    LT -> GT
    EQ -> EQ
    GT -> LT

toGraphLink: Link -> (List Note.Note) -> (Maybe GraphLink)
toGraphLink link notes =
  let
      source = findNote link.source notes
      target = findNote link.target notes
  in
    Maybe.map3 graphLinkBuilder source target (Just link.id)

initializeHistory: ((List CreateNoteRecord), (List CreateLinkRecord)) -> (List Action)
initializeHistory (noteRecords, linkRecords) =
  List.sortWith actionSorterDesc (List.map createNoteAction noteRecords ++ List.map createLinkAction linkRecords)

createNoteAction: CreateNoteRecord -> Action
createNoteAction note =
  CreateNote note.id False (HistoryNote note.action.id note.action.content note.action.source note.action.noteType)

createLinkAction: CreateLinkRecord -> Action
createLinkAction link =
  CreateLink link.id False (Link link.action.source link.action.target link.action.id)

actionSorterDesc: (Action -> Action -> Order)
actionSorterDesc actionA actionB =
  let
      idA = getHistoryId actionA
      idB = getHistoryId actionB
  in
    case compare idA idB of
       LT -> GT
       EQ -> EQ
       GT -> LT

getHistoryId: Action -> HistoryId
getHistoryId action =
  case action of 
    CreateNote id _ _ -> id
    CreateLink id _ _ -> id
    
graphLinkBuilder: Note.Note -> Note.Note -> LinkId -> GraphLink
graphLinkBuilder source target id =
  let
    sourceExtract = Note.extract source
    targetExtract = Note.extract target
  in
  GraphLink sourceExtract.intId sourceExtract.x sourceExtract.y targetExtract.intId targetExtract.x targetExtract.y id

toDescriptionNote: (List Note.Note) -> (List Link) -> Note.Note -> DescriptionNote
toDescriptionNote notes links note =
  let
    extract = Note.extract note
  in
    DescriptionNote extract.id extract.x extract.y extract.content extract.source []

-- getDescriptionLinks: (List Note.Note) -> Note.NoteId -> (List Link) -> (List DescriptionLink)
-- getDescriptionLinks notes noteId links =
--   List.map toDescriptionLink (List.map Note.extract (getLinkedNotes notes noteId links))

-- toDescriptionLink: Note.Extract -> DescriptionLink
-- toDescriptionLink extract =
--   DescriptionLink extract.id extract.intId extract.x extract.y

-- getLinkedNotes: (List Note.Note) -> Note.NoteId -> (List Link) -> (List Note.Note)
-- getLinkedNotes notes noteId links =
--   List.filterMap (maybeNoteFromLink notes noteId) links

-- maybeNoteFromLink: (List Note.Note) -> Note.NoteId -> Link -> (Maybe (Note.Note))
-- maybeNoteFromLink notes noteId link =
--   if link.source == noteId then 
--     findNote link.target notes
--   else if link.target == noteId then 
--     findNote link.source notes
--   else 
--     Nothing

findNote: Int -> (List Note.Note) -> (Maybe Note.Note)
findNote noteId notes =
  List.head (List.filter (Note.isNoteInt noteId) notes)

toHistoryAction: Action -> HistoryAction
toHistoryAction action = 
  case action of
    CreateNote id undone historyNote -> HistoryAction id undone (createNoteSummary historyNote)
    CreateLink id undone historyLink -> HistoryAction id undone (createLinkSummary historyLink)

createNoteSummary: HistoryNote -> String
createNoteSummary note =
  "Create Note:" ++  String.fromInt note.id ++
  " with Content: " ++ contentSummary note.content

contentSummary: String -> String
contentSummary content = String.slice 0 summaryLengthMin content ++ "..."


createLinkSummary: HistoryLink -> String
createLinkSummary link =
  "Create Link:" ++  String.fromInt link.id ++ 
  " from Source:" ++  String.fromInt link.source ++ 
  " to Target:" ++  String.fromInt link.target

toNoteRecord: MakeNoteRecord -> (List Note.Note) -> Note.NoteRecord
toNoteRecord note notes =
  Note.NoteRecord (getNextNoteId notes) note.content note.source note.noteType

getNextNoteId: (List Note.Note) -> Int
getNextNoteId notes = 
  case List.head notes of
    Just note -> Note.subsequentNoteId note
    Nothing -> 1

addNoteToNotes: Note.NoteRecord -> (List Note.Note) -> (List Link) -> (List Note.Note)
addNoteToNotes note notes links =
  initSimulation ( Note.init note :: notes) links

addNoteToActions : Note.NoteRecord -> (List Action) -> (List Action)
addNoteToActions note actions =
  CreateNote (getNextHistoryId actions) False (toHistoryNote note) :: actions

getNextHistoryId : (List Action) -> Int
getNextHistoryId actions =
  case List.head actions of
    Just action -> 
      case action of 
        CreateNote historyId _ _ -> historyId + 1
        CreateLink historyId _ _ -> historyId + 1
    Nothing -> 1

toHistoryNote: Note.NoteRecord -> HistoryNote
toHistoryNote note =
  HistoryNote note.id note.content note.source note.noteType

addLinkToLinks: Link -> (List Link) -> (List Link)
addLinkToLinks link links =
  link :: links

addLinkToActions: Link -> (List Action) -> (List Action)
addLinkToActions link actions =
  CreateLink (getNextHistoryId actions) False (toHistoryLink link) :: actions

toHistoryLink: Link -> HistoryLink
toHistoryLink link =
  HistoryLink link.source link.target link.id

toMaybeLink: MakeLinkRecord -> (List Link) -> (List Note.Note) -> (Maybe Link)
toMaybeLink makeLinkRecord links notes =
  let
      source = makeLinkRecord.source
      target = makeLinkRecord.target
  in
  
  if linkRecordIsValid source target notes then
    Just (Link source target (nextLinkId links))
  else 
    Nothing

linkRecordIsValid: Int -> Int -> (List Note.Note) -> Bool
linkRecordIsValid source target notes =
  noteExists source notes && noteExists target notes

noteExists: Int -> (List Note.Note) -> Bool
noteExists noteId notes =
  let
    extracts = List.map Note.extract notes
  in
  List.member noteId (List.map (\note -> note.intId) extracts)

nextLinkId: (List Link) -> Int
nextLinkId links =
  let
    mLink = List.head links
  in
    case mLink of
      Just link -> link.id + 1
      Nothing -> 1

getFormNotes: (List Note.Note) -> (List Link) -> (List LinkForm.FormNote)
getFormNotes notes links =
  notes
    |> List.filter Note.isSelected
    |> List.map (\note -> toFormNote note links)

toFormNote: Note.Note -> (List Link) -> LinkForm.FormNote
toFormNote note links =
  let
    extract = Note.extract note
  in
  LinkForm.FormNote extract.intId (contentSummary extract.content) (Note.isIndex note) (getNoteIds extract.intId links)

getNoteIds: Int -> (List Link) -> (List Int)
getNoteIds noteId links =
  List.filterMap (\link -> maybeGetNoteId noteId link) links

maybeGetNoteId: Int -> Link -> (Maybe Int)
maybeGetNoteId noteId link =
  if link.source == noteId then 
    Just link.target
  else if link.target == noteId then 
    Just link.source
  else 
    Nothing