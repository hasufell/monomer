{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}

module Monomer.Widget.Types where

import Data.Default
import Data.Map.Strict (Map)
import Data.Sequence (Seq, (<|), (|>))
import Data.Text (Text)
import Data.Typeable (cast, Typeable)

import qualified Data.Sequence as Seq

import Monomer.Common.Geometry
import Monomer.Common.Style
import Monomer.Common.Tree
import Monomer.Event.Types
import Monomer.Graphics.Renderer
import Monomer.Widget.PathContext

type Timestamp = Int
type WidgetType = String
type GlobalKeys s e = Map WidgetKey (Path, WidgetInstance s e)

data WidgetKey = WidgetKey Text deriving (Show, Eq, Ord)
data WidgetState = forall i . Typeable i => WidgetState i

data SizePolicy
  = StrictSize
  | FlexibleSize
  | RemainderSize
  deriving (Show, Eq)

data SizeReq = SizeReq {
  _sizeRequested :: Size,
  _sizePolicyWidth :: SizePolicy,
  _sizePolicyHeight :: SizePolicy
} deriving (Show, Eq)

instance Default SizeReq where
  def = SizeReq def FlexibleSize FlexibleSize

data WidgetRequest s
  = IgnoreParentEvents
  | IgnoreChildrenEvents
  | SetFocus Path
  | GetClipboard Path
  | SetClipboard ClipboardData
  | ResetOverlay Path
  | SetOverlay Path
  | UpdateUserState (s -> s)
  | forall i . Typeable i => SendMessage Path i
  | forall i . Typeable i => RunTask Path (IO i)
  | forall i . Typeable i => RunProducer Path ((i -> IO ()) -> IO ())

data WidgetResult s e = WidgetResult {
  _resultRequests :: Seq (WidgetRequest s),
  _resultEvents :: Seq e,
  _resultWidget :: WidgetInstance s e
}

instance Semigroup (WidgetResult s e) where
  er1 <> er2 = WidgetResult reqs evts widget where
    reqs = _resultRequests er1 <> _resultRequests er2
    evts = _resultEvents er1 <> _resultEvents er2
    widget = _resultWidget er2

data WidgetContext s e = WidgetContext {
  _wcScreenSize :: Size,
  _wcGlobalKeys :: GlobalKeys s e,
  _wcApp :: s,
  _wcInputStatus :: InputStatus,
  _wcTimestamp :: Int
}

data Widget s e =
  Widget {
    -- | Performs widget initialization
    _widgetInit :: WidgetContext s e -> PathContext -> WidgetInstance s e -> WidgetResult s e,
    -- | Returns the current internal state, which can later be used when merging widget trees
    _widgetGetState :: WidgetContext s e -> Maybe WidgetState,
    -- | Merges the current widget tree with the old one
    --
    -- Current app state
    -- Old instance
    -- New instance
    _widgetMerge :: WidgetContext s e -> PathContext -> WidgetInstance s e -> WidgetInstance s e -> WidgetResult s e,
    -- | Returns the list of focusable paths, if any
    --
    _widgetNextFocusable :: PathContext -> WidgetInstance s e -> Maybe Path,
    -- | Returns the path of the child item with the given coordinates
    _widgetFind :: Point -> WidgetInstance s e -> Maybe Path,
    -- | Handles an event
    --
    -- Current user state
    -- Path of focused widget
    -- Current widget path
    -- Event to handle
    --
    -- Returns: the list of generated events and, maybe, a new version of the widget if internal state changed
    _widgetHandleEvent :: WidgetContext s e -> PathContext -> SystemEvent -> WidgetInstance s e -> Maybe (WidgetResult s e),
    -- | Handles a custom message
    --
    -- Result of asynchronous computation
    --
    -- Returns: the list of generated events and a new version of the widget if internal state changed
    _widgetHandleMessage :: forall i . Typeable i => WidgetContext s e -> PathContext -> i -> WidgetInstance s e -> Maybe (WidgetResult s e),
    -- | Minimum size desired by the widget
    --
    -- Style options
    -- Preferred size for each of the children widgets
    -- Renderer (mainly for text sizing functions)
    --
    -- Returns: the minimum size desired by the widget
    _widgetPreferredSize :: forall m . Monad m => Renderer m -> WidgetContext s e -> WidgetInstance s e -> Tree SizeReq,
    -- | Resizes the children of this widget
    --
    -- Vieport assigned to the widget
    -- Region assigned to the widget
    -- Style options
    -- Preferred size for each of the children widgets
    --
    -- Returns: the size assigned to each of the children
    _widgetResize :: WidgetContext s e -> Rect -> Rect -> WidgetInstance s e -> Tree SizeReq -> WidgetInstance s e,
    -- | Renders the widget
    --
    -- Renderer
    -- The widget instance to render
    -- The current time in milliseconds
    --
    -- Returns: unit
    _widgetRender :: forall m . Monad m => Renderer m -> WidgetContext s e -> PathContext -> WidgetInstance s e -> m ()
  }

-- | Complementary information to a Widget, forming a node in the view tree
--
-- Type variables:
-- * n: Identifier for a node
data WidgetInstance s e =
  WidgetInstance {
    -- | Type of the widget
    _instanceType :: WidgetType,
    -- | Key/Identifier of the widget. If provided, it needs to be unique in the same hierarchy level (not globally)
    _instanceKey :: Maybe WidgetKey,
    -- | The actual widget
    _instanceWidget :: Widget s e,
    -- | The children widget, if any
    _instanceChildren :: Seq (WidgetInstance s e),
    -- | Indicates if the widget is enabled for user interaction
    _instanceEnabled :: Bool,
    -- | Indicates if the widget is visible
    _instanceVisible :: Bool,
    -- | Indicates whether the widget can receive focus
    _instanceFocusable :: Bool,
    -- | The visible area of the screen assigned to the widget
    _instanceViewport :: Rect,
    -- | The area of the screen where the widget can draw
    -- | Usually equal to _instanceViewport, but may be larger if the widget is wrapped in a scrollable container
    _instanceRenderArea :: Rect,
    -- | Style attributes of the widget instance
    _instanceStyle :: Style
  }
